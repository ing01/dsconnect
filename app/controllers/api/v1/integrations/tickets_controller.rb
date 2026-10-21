# A API de Integracao de Tickets: o que um sistema EXTERNO (hoje, a IA de
# triagem de outro time) usa para ler um ticket e, depois de analisar,
# escrever de volta pra onde ele deve ir. So' leitura + o roteamento - nenhuma
# das outras 15 acoes de Api::V1::Accounts::TicketsController (fechar,
# mesclar, criar filho...) faz sentido para quem so' decide Mesa/Estagio.
class Api::V1::Integrations::TicketsController < Api::V1::Integrations::BaseController
  DEFAULT_PER_PAGE = 25

  # As mesmas associacoes de Api::V1::Accounts::TicketsController::DETAIL_INCLUDES,
  # menos o que e' so'-interno (ticket_activities, ticket_followers,
  # ticket_sla_extensions, service_catalog_item): a IA externa nao precisa de
  # auditoria nem de SLA pra decidir roteamento, e `ticket_comments` nunca
  # entra aqui de proposito - e' a thread interna da equipe.
  SHOW_INCLUDES = [
    :team, :ticket_column, :ticket_category, :ticket_complexity, :company, :contact,
    { conversations: :contact },
    { ticket_customer_communications: [:user, :contact] },
    { ticket_attachments: { file_attachment: :blob } }
  ].freeze

  def index
    @tickets_count = filtered_tickets.count
    @current_page = (params[:page] || 1).to_i
    @tickets = filtered_tickets.order(created_at: :desc).page(@current_page).per(params[:per_page] || DEFAULT_PER_PAGE)
  end

  def show
    @ticket = current_account.tickets.includes(SHOW_INCLUDES).find(ticket_id_param)
  end

  # A IA aplica a decisao de roteamento. `team_id` e' o unico obrigatorio -
  # mover de Mesa/Estagio e' o proposito deste endpoint; classificar
  # (categoria/complexidade/catalogo) e' so' quando a IA tiver essa resposta.
  def route
    @ticket = current_account.tickets.find(ticket_id_param)
    apply_transfer
    apply_classification
    apply_category_and_complexity
    post_routing_note
    @ticket.reload
    render :show
  end

  private

  def ticket_id_param
    params[:id]
  end

  def filtered_tickets
    scope = current_account.tickets.includes(:team, :ticket_column, :ticket_category, :company)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(team_id: params[:team_id]) if params[:team_id].present?
    scope = scope.where(created_at: params[:created_after]..) if params[:created_after].present?
    scope
  end

  def apply_transfer
    return if route_params[:team_id].blank?

    Tickets::TransferService.new(
      ticket: @ticket, user: nil,
      attributes: route_params.slice(:team_id, :ticket_column_id)
    ).perform
  end

  def apply_classification
    return if route_params[:service_catalog_item_id].blank?

    item = ServiceCatalogItem.joins(service_catalog_area: :service_catalog)
                             .where(service_catalogs: { account_id: current_account.id })
                             .find(route_params[:service_catalog_item_id])
    @ticket.classify!(item, nil)
  end

  # Validado contra a MESMA conta explicitamente (diferente da acao `update`
  # do painel, que confia no usuario logado so' poder ver ids da propria
  # conta pela UI) - aqui quem chama e' um sistema externo, e um id de outra
  # conta so' deve estourar 404, nunca ser aceito.
  def apply_category_and_complexity
    if route_params[:ticket_category_id].present?
      @ticket.update!(ticket_category: @ticket.team.ticket_categories.find(route_params[:ticket_category_id]))
    end
    return if route_params[:ticket_complexity_id].blank?

    @ticket.update!(ticket_complexity: current_account.ticket_complexities.find(route_params[:ticket_complexity_id]))
  end

  # `TicketComment` exige um `user` humano (nao e opcional no model) - sem
  # ator humano aqui, uso a mesma trilha que Tickets::ColumnAutomationService
  # ja usa pra "nota automatica sem usuario": uma TicketActivity com
  # `activity_type: :automation_note`, que a aba Atividades do ticket ja sabe
  # renderizar.
  def post_routing_note
    return if route_params[:note].blank?

    @ticket.ticket_activities.create!(
      account_id: current_account.id, user: nil, activity_type: :automation_note,
      new_value: "Direcionado automaticamente pela IA de triagem: #{route_params[:note]}"
    )
  end

  def route_params
    params.permit(:team_id, :ticket_column_id, :service_catalog_item_id, :ticket_category_id,
                  :ticket_complexity_id, :note)
  end
end
