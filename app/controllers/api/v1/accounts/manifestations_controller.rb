# O SAC do lado da equipe.
#
# Lista, detalhe, mudanca de status, atribuicao de responsavel, respostas,
# anotacoes internas e a conversao em ticket.
class Api::V1::Accounts::ManifestationsController < Api::V1::Accounts::BaseController
  LIST_INCLUDES = [:company, :contact, :assignee].freeze
  DETAIL_INCLUDES = [:company, :contact, :assignee, :converted_ticket, :converted_suggestion,
                     { manifestation_attachments: { file_attachment: :blob } }].freeze

  before_action :fetch_manifestation, only: [:show, :update, :destroy, :convert, :convert_to_suggestion]
  before_action :check_authorization

  def index
    escopo = Current.account.manifestations.includes(*LIST_INCLUDES)
    @manifestations = ManifestationFinder.new(scope: escopo, params: params).perform.ordered
    # Os contadores do topo da tela. Contados no servidor para que a tela nao
    # precise baixar tudo so para somar.
    @counts = {
      total: Current.account.manifestations.count,
      pending: Current.account.manifestations.pending.count,
      untouched: Current.account.manifestations.untouched.count
    }
  end

  def show
    load_detail_lists
  end

  # A equipe registra uma manifestacao recebida por telefone ou presencialmente.
  # E o mesmo canal, so que anotado por quem ouviu - por isso o solicitante vem
  # no pedido, diferente do Portal, onde ele e sempre o contato logado.
  def create
    @manifestation = Current.account.manifestations.new(manifestation_params)
    @manifestation.status ||= :received

    ActiveRecord::Base.transaction do
      @manifestation.save!
      @manifestation.manifestation_activities.create!(
        user: Current.user, activity_type: :created, new_value: @manifestation.status
      )
    end

    load_detail_lists
    render 'show', status: :created
  end

  # Status e responsavel, cada mudanca registrada no historico com autor e hora.
  def update
    anterior = { status: @manifestation.status, assignee_id: @manifestation.assignee_id }

    ActiveRecord::Base.transaction do
      @manifestation.update!(manifestation_params)
      log_status_change(anterior[:status])
      log_assignee_change(anterior[:assignee_id])
    end

    load_detail_lists
    render 'show'
  end

  # Converter em ticket. O servico recusa se ja houve conversao - e o que impede
  # duas aberturas para a mesma manifestacao.
  def convert
    @ticket = Manifestations::TicketConversionService.new(
      manifestation: @manifestation,
      user: Current.user,
      team: Current.account.teams.find_by(id: params[:team_id]),
      category: TicketCategory.joins(:team).where(teams: { account_id: Current.account.id })
                              .find_by(id: params[:ticket_category_id])
    ).perform

    @manifestation.reload
    load_detail_lists
    render 'show'
  rescue Manifestations::TicketConversionService::AlreadyConverted,
         Manifestations::TicketConversionService::NoTeamAvailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Converter no quadro de Sugestoes em vez de virar ticket - sem Mesa/Time, a
  # unica entrada e' a propria manifestacao.
  def convert_to_suggestion
    Manifestations::SuggestionConversionService.new(manifestation: @manifestation, user: Current.user).perform

    @manifestation.reload
    load_detail_lists
    render 'show'
  rescue Manifestations::SuggestionConversionService::AlreadyConverted,
         Manifestations::SuggestionConversionService::NoColumnAvailable => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @manifestation.destroy!
    head :ok
  end

  private

  def fetch_manifestation
    @manifestation = Current.account.manifestations.includes(*DETAIL_INCLUDES).find(params[:id])
  end

  # A equipe ve as duas listas: as respostas publicas E as anotacoes internas.
  def load_detail_lists
    @messages = @manifestation.manifestation_messages.includes(:user, :contact).chronological
    @activities = @manifestation.manifestation_activities.includes(:user, :contact).chronological
  end

  def manifestation_params
    params.require(:manifestation).permit(:title, :description, :kind, :subject_area,
                                          :status, :assignee_id, :company_id, :contact_id)
  end

  def log_status_change(anterior)
    return if @manifestation.status == anterior

    @manifestation.manifestation_activities.create!(
      user: Current.user, activity_type: :status_changed,
      previous_value: anterior, new_value: @manifestation.status
    )
  end

  def log_assignee_change(anterior)
    return if @manifestation.assignee_id == anterior

    @manifestation.manifestation_activities.create!(
      user: Current.user, activity_type: :assignee_changed,
      previous_value: anterior&.to_s, new_value: @manifestation.assignee_id&.to_s
    )
  end

  # O `check_authorization` herdado ja pergunta ao policy o metodo com o nome da
  # action - `convert` cai em `convert?`, que e so do administrador. O que ele
  # nao sabe sozinho e o registro: sem isto, `index` instanciaria um
  # Manifestation vazio.
  def check_authorization(model = nil)
    super(model || @manifestation || Manifestation)
  end
end
