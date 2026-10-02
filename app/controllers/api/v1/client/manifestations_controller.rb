# O SAC na Area do Cliente: registrar manifestacao, acompanhar e responder.
#
# Como todo controller daqui, nenhuma acao monta a propria consulta: todas partem
# de `visible_manifestations`, que vive no contato. Trocar o id na URL nao
# alcanca manifestacao de outra empresa porque a busca nunca sai desse escopo.
class Api::V1::Client::ManifestationsController < Api::V1::Client::BaseController
  # O que a tela do cliente le. `visible_to_client` nos includes tambem - sem
  # isso o pre-carregamento traria as notas internas para a memoria, e bastaria
  # uma view distraida para vaza-las.
  DETAIL_INCLUDES = [:company, :contact, :assignee, :converted_ticket,
                     { manifestation_attachments: { file_attachment: :blob } }].freeze

  before_action :fetch_manifestation, only: [:show]

  def index
    @manifestations = current_contact.visible_manifestations
                                     .includes(:company, :contact, :assignee)
                                     .ordered
  end

  def show
    # As duas listas que o detalhe mostra, carregadas aqui para a view nao
    # precisar decidir o que e visivel.
    @messages = @manifestation.manifestation_messages
                              .visible_to_client
                              .includes(:user, :contact)
                              .chronological
    @activities = @manifestation.manifestation_activities
                                .includes(:user, :contact)
                                .chronological
  end

  # O registro pelo cliente.
  #
  # Ele informa o QUE aconteceu - tipo, assunto, titulo, descricao, arquivos.
  # Empresa e solicitante nao vem do formulario: sao os do contato logado,
  # gravados aqui. Mandar outro id no corpo nao muda nada, porque os campos
  # sequer sao lidos dos parametros.
  def create
    @manifestation = build_manifestation

    ActiveRecord::Base.transaction do
      @manifestation.save!
      attach_uploaded_files!
      log_creation!
    end

    @messages = []
    @activities = @manifestation.manifestation_activities.includes(:user, :contact).chronological
    render 'show', status: :created
  end

  private

  def fetch_manifestation
    @manifestation = current_contact.visible_manifestations
                                    .includes(*DETAIL_INCLUDES)
                                    .find(params[:id])
  end

  # So o que o cliente decide. Status, responsavel interno, empresa e solicitante
  # ficam fora da lista - nao e que sejam ignorados depois: eles nunca chegam a
  # ser lidos.
  def permitted_params
    params.permit(:title, :description, :kind, :subject_area)
  end

  # A empresa: a do contato. Quem pertence a mais de uma pode dizer qual, mas
  # somente entre as DELE - `client_company_ids` e a fronteira, e um id de fora
  # cai na primeira empresa dele em vez de ser aceito.
  def company_for_new_manifestation
    permitidas = current_contact.client_company_ids
    escolhida = params[:company_id].presence&.to_i
    permitidas.include?(escolhida) ? escolhida : permitidas.first
  end

  def build_manifestation
    manifestacao = Current.account.manifestations.new(permitted_params)
    manifestacao.company_id = company_for_new_manifestation
    manifestacao.contact_id = current_contact.id
    # Toda manifestacao nasce "Recebida": o andamento e da equipe.
    manifestacao.status = :received
    manifestacao
  end

  def attach_uploaded_files!
    Array(params[:attachments]).reject(&:blank?).each do |arquivo|
      anexo = @manifestation.manifestation_attachments.new(
        account_id: @manifestation.account_id,
        contact: current_contact
      )
      anexo.file.attach(arquivo)
      anexo.save!
    end
  end

  def log_creation!
    @manifestation.manifestation_activities.create!(
      contact: current_contact,
      activity_type: :created,
      new_value: @manifestation.status
    )
  end
end
