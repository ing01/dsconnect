# Registra um preenchimento de Formulario, venha de onde vier: agente (painel), cliente logado
# (Central de Ajuda / Area do Cliente) ou visitante (formulario aberto). Cria o FormResponse e um
# FormAnswer por pergunta, depois de validar tudo - nada fica gravado pela metade.
#
# Quem preenche de fora (cliente, visitante) manda texto e arquivos de uma pessoa desconhecida:
#   - so' perguntas que existem no formulario sao aceitas (o resto e' ignorado);
#   - em escolha unica/multipla e lista, o valor tem de ser uma das opcoes;
#   - o texto tem limite de tamanho e a data tem de ser uma data;
#   - arquivo: so' tipos comuns (imagem, PDF, Office, texto) e ate 10 MB quando o formulario e' aberto.
class Forms::SubmitService
  class InvalidSubmission < StandardError; end

  MAX_TEXT_LENGTH = 5_000
  OPEN_MAX_FILE_SIZE = 10.megabytes
  OPEN_ALLOWED_TYPES = %w[
    image/png image/jpeg image/gif image/webp application/pdf text/plain text/csv
    application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ].freeze

  pattr_initialize [:form!, :source!, { answers: {}, files: {}, ticket: nil, user: nil, contact: nil, respondent: {} }]

  def perform
    raise InvalidSubmission, 'o formulário ainda não foi publicado' unless form.published?

    check_fields!
    ActiveRecord::Base.transaction do
      response = form.form_responses.create!(response_attributes)
      build_answers(response)
      response
    end
  end

  private

  def response_attributes
    {
      account: form.account, ticket: ticket, filled_by: user, contact: contact, source: source,
      respondent_name: respondent[:name].to_s.strip.presence&.first(120),
      respondent_email: respondent[:email].to_s.strip.presence&.first(160)
    }
  end

  def given_answers
    @given_answers ||= to_plain_hash(answers)
  end

  def given_files
    @given_files ||= to_plain_hash(files)
  end

  def to_plain_hash(value)
    (value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h).stringify_keys
  end

  def fields
    @fields ||= Array(form.fields)
  end

  def check_fields!
    problems = fields.filter_map { |field| problem_with(field) }
    raise InvalidSubmission, problems.join('; ') if problems.any?
  end

  def problem_with(field)
    label = field['label'].presence || 'pergunta'
    return file_problem(field, label) if field['field_type'] == 'file_upload'

    values = Array(given_answers[field['id']]).map(&:to_s).compact_blank
    return "preencha: #{label}" if field['required'] && values.empty?

    value_problem(field, values, label)
  end

  def value_problem(field, values, label)
    return "#{label}: texto muito longo" if values.any? { |value| value.length > MAX_TEXT_LENGTH }
    return "#{label}: escolha só uma opção" if values.size > 1 && field['field_type'] != 'multiple_choice'

    type_problem(field, values, label)
  end

  def type_problem(field, values, label)
    return "#{label}: escolha uma das opções" if choice?(field) && (values - Array(field['options'])).any?
    return "#{label}: data inválida" if field['field_type'] == 'date' && values.any? { |value| !valid_date?(value) }

    nil
  end

  def choice?(field)
    %w[single_choice multiple_choice dropdown].include?(field['field_type'])
  end

  def valid_date?(value)
    Date.iso8601(value)
    true
  rescue ArgumentError
    false
  end

  def file_problem(field, label)
    file = given_files[field['id']]
    return (field['required'] ? "envie o arquivo: #{label}" : nil) if file.blank?
    return nil unless source == 'public'

    return "#{label}: arquivo acima de #{OPEN_MAX_FILE_SIZE / 1.megabyte} MB" if file.size > OPEN_MAX_FILE_SIZE
    return "#{label}: tipo de arquivo não permitido" unless OPEN_ALLOWED_TYPES.include?(file.content_type.to_s)

    nil
  end

  def build_answers(response)
    fields.each do |field|
      if field['field_type'] == 'file_upload'
        attach_file(response, field)
      else
        save_value(response, field)
      end
    end
  end

  def save_value(response, field)
    values = Array(given_answers[field['id']]).map(&:to_s).compact_blank
    return if values.empty?

    response.form_answers.create!(account: form.account, field_id: field['id'],
                                  value: field['field_type'] == 'multiple_choice' ? values : values.first)
  end

  def attach_file(response, field)
    file = given_files[field['id']]
    return if file.blank?

    answer = response.form_answers.create!(account: form.account, field_id: field['id'])
    answer.file.attach(file)
  end
end
