# "Converter em Sugestao": quando a manifestacao nao e um atendimento de
# verdade - e uma melhoria, sugestao ou bug do sistema interno - ela entra no
# quadro de Sugestoes em vez de virar ticket numa Mesa.
#
# Espelha Manifestations::TicketConversionService, trocando o destino: nao ha
# Mesa/Time/Categoria aqui (o quadro de Sugestoes e' por CONTA, uma unica
# fila - ver SuggestionColumn), entao a unica decisao e' converter ou nao.
#
# A conversao e IRREVERSIVEL e UNICA: `Manifestation#converted?` olha os dois
# destinos possiveis (ticket OU sugestao), entao uma manifestacao ja
# convertida em ticket tambem nao pode virar sugestao, e vice-versa.
class Manifestations::SuggestionConversionService
  class AlreadyConverted < StandardError; end
  class NoColumnAvailable < StandardError; end

  def initialize(manifestation:, user:)
    @manifestation = manifestation
    @user = user
  end

  def perform
    raise AlreadyConverted, I18n.t('manifestations.convert.already_done') if @manifestation.converted?

    ActiveRecord::Base.transaction do
      suggestion = build_suggestion
      suggestion.save!
      copy_attachments!(suggestion)
      link!(suggestion)
      log!(suggestion)
      suggestion
    end
  end

  private

  attr_reader :manifestation, :user

  def account
    manifestation.account
  end

  # Sem Estagio nenhum nao ha onde o cartao entrar - falhar aqui e melhor do
  # que criar uma Sugestao fora de qualquer coluna do quadro.
  def entry_column
    account.suggestion_columns.order(:position, :id).first
  end

  def build_suggestion
    column = entry_column
    raise NoColumnAvailable, I18n.t('manifestations.convert.no_suggestion_column') if column.blank?

    account.suggestions.new(
      title: manifestation.title,
      # Mesmo cabecalho do ticket convertido: quem olha a Sugestao precisa
      # saber que ela veio do SAC, e o numero para voltar la.
      description: converted_description,
      suggestion_column: column,
      # Quem registra no quadro e' sempre quem converteu - Suggestion exige um
      # `user` (o autor), e aqui o autor e' o agente, nao o cliente.
      user: user
    )
  end

  def converted_description
    I18n.t('manifestations.convert.description_header',
           reference: manifestation.reference,
           kind: I18n.t("manifestations.kinds.#{manifestation.kind}"),
           subject: I18n.t("manifestations.subject_areas.#{manifestation.subject_area}")) +
      "\n\n#{manifestation.description}"
  end

  # Sugestao so aceita imagem/video (Suggestion#attachments_within_limits) -
  # diferente do ticket, que aceita qualquer arquivo. Um anexo fora desses
  # tipos (ex: um PDF) fica so na manifestacao original, sem quebrar a
  # conversao inteira por causa de um arquivo que o quadro nao exibe mesmo.
  def copy_attachments!(suggestion)
    manifestation.manifestation_attachments.each do |origem|
      next unless origem.file.attached?
      next unless origem.file.content_type.to_s.start_with?('image/', 'video/')

      suggestion.attachments.attach(origem.file.blob)
    end
  end

  def link!(suggestion)
    manifestation.update!(
      converted_suggestion: suggestion,
      converted_at: Time.current,
      status: :in_progress
    )
  end

  def log!(suggestion)
    manifestation.manifestation_activities.create!(
      user: user,
      activity_type: :converted_to_suggestion,
      new_value: suggestion.title,
      meta: { suggestion_id: suggestion.id }
    )
  end
end
