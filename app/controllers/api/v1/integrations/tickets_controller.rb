# A API de Integracao de Tickets: o que um sistema EXTERNO (hoje, a IA de
# triagem de outro time, e o fluxo de desenvolvimento que sincroniza com o
# Jira) usa para ler, criar e rotear tickets. `ticket_comments` continua de
# fora de proposito (ver READ_INCLUDES) - e' a thread interna da equipe -,
# mas tem rota propria de LEITURA em Api::V1::Integrations::TicketCommentsController.
class Api::V1::Integrations::TicketsController < Api::V1::Integrations::BaseController
  DEFAULT_PER_PAGE = 25

  # As mesmas associacoes de Api::V1::Accounts::TicketsController::DETAIL_INCLUDES,
  # menos o que e' so'-interno (ticket_activities, ticket_followers,
  # ticket_sla_extensions, service_catalog_item): a IA externa nao precisa de
  # auditoria nem de SLA pra decidir roteamento, e `ticket_comments` nunca
  # entra aqui de proposito - e' a thread interna da equipe (ver TicketCommentsController
  # para a rota de leitura dedicada).
  SHOW_INCLUDES = [
    :team, :ticket_column, :ticket_category, :ticket_complexity, :company, :contact, :assignee,
    { conversations: :contact },
    { ticket_customer_communications: [:user, :contact] },
    { ticket_attachments: { file_attachment: :blob } }
  ].freeze

  # `priority=` (enum) levanta ArgumentError pra um valor fora de
  # low/medium/high/urgent - sem isto a chamada estourava 500 em vez de um
  # 422 explicando o motivo.
  rescue_from ArgumentError, with: :render_argument_error

  def index
    @tickets_count = filtered_tickets.count
    @current_page = (params[:page] || 1).to_i
    @tickets = filtered_tickets.order(created_at: :desc).page(@current_page).per(params[:per_page] || DEFAULT_PER_PAGE)
  end

  def show
    @ticket = current_account.tickets.includes(SHOW_INCLUDES).find(ticket_id_param)
  end

  # Abre um ticket direto pela API (ex.: a aba "Abrir chamado" de um sistema
  # externo, ou um chamado SEFAZ gerado automaticamente). Mesmas exigencias
  # de sempre (TicketOpening): title, description, priority e
  # ticket_category_id sao obrigatorios na criacao, igual ao painel - esta
  # API nao abre excecao nenhuma a essa regra.
  def create
    @ticket = current_account.tickets.new(create_params)
    @ticket.origin = 'integration_api'
    @ticket.team_id ||= @ticket.ticket_column&.team_id
    @ticket.save!
    @ticket.reload
    render :show, status: :created
  end

  # A IA aplica a decisao de roteamento. `team_id` e' o unico obrigatorio -
  # mover de Mesa/Estagio e' o proposito deste endpoint; classificar
  # (categoria/complexidade/catalogo), responsavel, prioridade e os atributos
  # personalizados sao todos opcionais, aplicados so' quando enviados.
  def route
    @ticket = current_account.tickets.find(ticket_id_param)
    apply_transfer
    apply_classification
    apply_category_and_complexity
    apply_assignee
    apply_priority
    apply_custom_attributes
    post_routing_note
    @ticket.reload
    render :show
  end

  private

  def ticket_id_param
    params[:id]
  end

  # Um filtro de igualdade por parametro->coluna; `created_after`/`updated_after`
  # sao faixa (`..`), tratados a parte por nao caberem no mesmo molde de `where`.
  EQUALITY_FILTERS = {
    status: :status, team_id: :team_id, ticket_column_id: :ticket_column_id,
    ticket_category_id: :ticket_category_id, company_id: :company_id, assignee_id: :assignee_id
  }.freeze

  def filtered_tickets
    scope = current_account.tickets.includes(:team, :ticket_column, :ticket_category, :company, :assignee)
    scope = apply_equality_filters(scope)
    scope = scope.where(created_at: params[:created_after]..) if params[:created_after].present?
    scope = scope.where(updated_at: params[:updated_after]..) if params[:updated_after].present?
    scope
  end

  def apply_equality_filters(scope)
    EQUALITY_FILTERS.reduce(scope) do |current_scope, (param_name, column)|
      next current_scope if params[param_name].blank?

      current_scope.where(column => params[param_name])
    end
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

  # So' o Nivel 1 (`assignee_id`) - os niveis 2-5 do Modulo de Responsaveis
  # continuam so' pelo painel por ora, ninguem pediu roteamento externo por
  # nivel ainda.
  def apply_assignee
    return if route_params[:assignee_id].blank?

    @ticket.update!(assignee: current_account.users.find(route_params[:assignee_id]))
  end

  def apply_priority
    return if route_params[:priority].blank?

    @ticket.update!(priority: route_params[:priority])
  end

  # MERGE, nao substitui: ao contrario do PATCH do painel (que troca o jsonb
  # inteiro porque a tela sempre manda o objeto completo), quem chama aqui e'
  # um sistema externo que so' conhece os proprios campos (ex.: analise,
  # observacoes do dev, horas) - substituir apagaria qualquer chave gravada
  # por outro caminho (o formulario de abertura, por exemplo).
  def apply_custom_attributes
    return if route_params[:custom_attributes].blank?

    @ticket.update!(custom_attributes: @ticket.custom_attributes.merge(route_params[:custom_attributes].to_h))
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
                  :ticket_complexity_id, :assignee_id, :priority, :note, custom_attributes: {})
  end

  def create_params
    params.require(:ticket).permit(
      :title, :description, :priority, :team_id, :ticket_column_id, :company_id, :contact_id,
      :ticket_category_id, :ticket_complexity_id, :assignee_id, :due_date, custom_attributes: {}
    )
  end

  def render_argument_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
