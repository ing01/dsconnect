# A API de Integracao de Tickets: o que um sistema EXTERNO (hoje, a IA de
# triagem de outro time, e o fluxo de desenvolvimento que sincroniza com o
# Jira) usa para ler, criar e rotear tickets. `ticket_comments` continua de
# fora de proposito (ver READ_INCLUDES) - e' a thread interna da equipe -,
# mas tem rota propria de LEITURA em Api::V1::Integrations::TicketCommentsController.
class Api::V1::Integrations::TicketsController < Api::V1::Integrations::BaseController
  DEFAULT_PER_PAGE = 25

  # Os campos do card do Jira (Observacoes do Desenvolvedor, Observacoes Sobre o
  # Teste, Documentacao, Instrucoes, Analise). Guardados em `custom_attributes`,
  # mas expostos tambem como campos de primeiro nivel - na leitura (lista e
  # ticket) e na escrita (criar e atualizar), pra quem integra nao precisar
  # conhecer onde ficam.
  DEV_FIELDS = Ticket::LONG_TEXT_CUSTOM_ATTRIBUTES

  TRIAGE_NOTE_PREFIX = 'Direcionado automaticamente pela IA de triagem:'.freeze

  # Uma regra do pedido violada (Estagio fora da Mesa, sprint de outra Mesa, valor
  # de enum invalido...): 422 com o campo recusado em `attributes`. Id que nao
  # existe ou e' de OUTRA conta continua sendo 404, nunca 422.
  class InvalidRequest < StandardError
    attr_reader :field

    def initialize(message, field: nil)
      super(message)
      @field = field
    end
  end

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
  rescue_from InvalidRequest, with: :render_invalid_request

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
    @ticket = current_account.tickets.new(create_attributes)
    @ticket.origin = 'integration_api'
    @ticket.team_id ||= @ticket.ticket_column&.team_id
    validate_new_dev_fields!
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
    # Numa transacao so': um erro no meio (sprint de outra Mesa, categoria de outra
    # Mesa...) desfaz o que ja tinha sido aplicado, em vez de deixar o ticket meio alterado.
    ActiveRecord::Base.transaction do
      apply_transfer
      apply_classification
      apply_category_and_complexity
      apply_assignee
      apply_priority
      apply_dev_fields
      apply_custom_attributes
      post_routing_note
    end
    @ticket.reload
    render :show
  end

  # `PATCH /tickets/:id` - o mesmo que `route`, com o nome REST que quem
  # integra espera para editar um ticket.
  alias update route

  private

  def ticket_id_param
    params[:id]
  end

  # Um filtro de igualdade por parametro->coluna; `created_after`/`updated_after`
  # sao faixa (`..`), tratados a parte por nao caberem no mesmo molde de `where`.
  EQUALITY_FILTERS = {
    status: :status, team_id: :team_id, ticket_column_id: :ticket_column_id,
    ticket_category_id: :ticket_category_id, company_id: :company_id, assignee_id: :assignee_id,
    sprint_id: :sprint_id, development_type: :development_type
  }.freeze

  def filtered_tickets
    # Valor fora de bug/task/story e' 422: no filtro de igualdade ele viraria "sem tipo".
    checked_development_type(params[:development_type]) if params[:development_type].present?
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
    team_id, column_id = destination
    return if column_id.blank?

    guard_sprint_on_team_change!(team_id)
    Tickets::TransferService.new(
      ticket: @ticket, user: nil, attributes: { team_id: team_id, ticket_column_id: column_id }
    ).perform
  end

  # Para onde o ticket vai - a MESMA regra do `create`, que ja deduzia a Mesa:
  #   - so' `ticket_column_id`: a Mesa e' a do Estagio (antes o Estagio sozinho era
  #     descartado em silencio);
  #   - so' `team_id`: o primeiro Estagio da Mesa (sem mudar se ja esta nela);
  #   - os dois: o Estagio tem de ser da Mesa, senao 422;
  #   - nenhum: nao move. Em branco tambem e' "nao move" - e' o que a IA manda quando
  #     nao decidiu aquele campo.
  # Mesa e Estagio sao procurados NA CONTA da chave: de outra conta, 404.
  def destination
    team = current_account.teams.find(route_params[:team_id]) if route_params[:team_id].present?
    column = current_account.ticket_columns.find(route_params[:ticket_column_id]) if route_params[:ticket_column_id].present?
    return [nil, nil] if team.nil? && column.nil?

    if column
      raise InvalidRequest.new('ticket_column_id does not belong to team_id', field: 'ticket_column_id') if team && column.team_id != team.id

      [column.team_id, column.id]
    else
      [team.id, first_column_of(team)&.id]
    end
  end

  def first_column_of(team)
    return nil if team.id == @ticket.team_id

    team.ticket_columns.order(:position, :id).first ||
      raise(InvalidRequest.new('the Mesa has no stages (ticket_column_id)', field: 'team_id'))
  end

  # Trocar de Mesa deixaria o ticket num sprint de outra Mesa. Em vez de limpar em
  # silencio, pede que quem chama diga para onde ele vai (`sprint_id`, em branco = Backlog).
  def guard_sprint_on_team_change!(team_id)
    return if team_id == @ticket.team_id || @ticket.sprint_id.blank? || route_params.key?(:sprint_id)

    raise InvalidRequest.new('the ticket is in a Sprint of its current Mesa; send sprint_id (blank for Backlog) together with the new Mesa',
                             field: 'sprint_id')
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

  # Campos do desenvolvimento: `development_type` (bug, task, story; em branco limpa) e
  # `sprint_id` (da MESMA Mesa do ticket; em branco = Backlog).
  def apply_dev_fields
    attributes = {}
    attributes[:development_type] = checked_development_type(route_params[:development_type]) if route_params.key?(:development_type)
    attributes[:sprint_id] = checked_sprint_id(route_params[:sprint_id], @ticket.team_id) if route_params.key?(:sprint_id)
    @ticket.update!(attributes) if attributes.any?
  end

  def validate_new_dev_fields!
    @ticket.development_type = checked_development_type(@ticket.development_type) if @ticket.development_type.present?
    return if @ticket.sprint_id.blank?

    checked_sprint_id(@ticket.sprint_id, @ticket.team_id)
  end

  def checked_development_type(value)
    return nil if value.blank?
    return value.to_s if Ticket.development_types.key?(value.to_s)

    raise InvalidRequest.new("development_type must be one of: #{Ticket.development_types.keys.join(', ')}", field: 'development_type')
  end

  # Sprint da conta (de outra conta ou inexistente: 404) e da Mesa do ticket (422).
  def checked_sprint_id(value, team_id)
    return nil if value.blank?

    sprint = Sprint.where(account_id: current_account.id).find(value)
    raise InvalidRequest.new('sprint_id belongs to another Mesa', field: 'sprint_id') if sprint.team_id != team_id

    sprint.id
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
    incoming = merged_custom_attributes(route_params)
    return if incoming.blank?

    @ticket.update!(custom_attributes: @ticket.custom_attributes.merge(incoming))
  end

  # `custom_attributes` + os campos do Jira vindos como primeiro nivel (estes
  # ganham se a mesma chave vier nos dois).
  def merged_custom_attributes(source)
    source[:custom_attributes].to_h.merge(source.slice(*DEV_FIELDS).to_h)
  end

  def create_attributes
    base = create_params.except(*DEV_FIELDS, :custom_attributes).to_h
    custom = merged_custom_attributes(create_params)
    custom.present? ? base.merge(custom_attributes: custom) : base
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
      new_value: triage_note? ? "#{TRIAGE_NOTE_PREFIX} #{route_params[:note]}" : route_params[:note].to_s,
      meta: { source: triage_note? ? 'triage' : 'integration' }
    )
  end

  # O `route` e' o fluxo da triagem por IA, entao a nota leva o prefixo dela - a menos
  # que quem chama mande `triage: false`: ai o texto vai exatamente como veio (uma nota
  # de um sistema que nao e' a triagem nao deve parecer da IA).
  def triage_note?
    ActiveModel::Type::Boolean.new.cast(route_params.fetch(:triage, true)) != false
  end

  def route_params
    params.permit(:team_id, :ticket_column_id, :service_catalog_item_id, :ticket_category_id,
                  :ticket_complexity_id, :assignee_id, :priority, :note, :triage, :sprint_id, :development_type,
                  *DEV_FIELDS, custom_attributes: {})
  end

  def create_params
    params.require(:ticket).permit(
      :title, :description, :priority, :team_id, :ticket_column_id, :company_id, :contact_id,
      :ticket_category_id, :ticket_complexity_id, :assignee_id, :due_date, :sprint_id, :development_type,
      *DEV_FIELDS, custom_attributes: {}
    )
  end

  def render_argument_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  # `error` e `message` com o mesmo texto: a API tem os dois formatos de 422 (a
  # validacao do model usa `message`/`attributes`), e quem consome pode ler qualquer um.
  def render_invalid_request(exception)
    render json: { error: exception.message, message: exception.message, attributes: [exception.field].compact },
           status: :unprocessable_entity
  end
end
