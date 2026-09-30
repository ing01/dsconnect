# Os tickets na Area do Cliente: o Kanban, o detalhe e a abertura.
#
# Nenhuma acao monta a propria consulta - todas partem de `visible_tickets`, na
# base. Trocar o id na URL nao alcanca ticket de outra empresa porque a busca
# nunca sai desse escopo.
class Api::V1::Client::TicketsController < Api::V1::Client::BaseController
  BOARD_INCLUDES = [:ticket_column, :ticket_category, :team, :company, :contact,
                    *AssigneeLeveled.assignee_associations,
                    { conversations: :contact }].freeze

  DETAIL_INCLUDES = [:ticket_column, :ticket_category, :team, :contact,
                     :ticket_checklist_items, :calendar_events,
                     { ticket_customer_communications: [:contact, :user, { ticket_attachments: { file_attachment: :blob } }] }].freeze

  before_action :fetch_ticket, only: [:show]

  # O quadro. Agrupado pelos Estagios da Mesa escolhida, como o Kanban interno -
  # as mesmas Mesas e os mesmos Estagios, so que sem nada que o cliente nao
  # deva ver.
  def index
    @teams = client_teams
    @team = pick_team
    @companies = client_companies
    @columns = @team ? @team.ticket_columns.order(:position, :id) : TicketColumn.none
    # `operational`: resolvido, fechado e cancelado saem do quadro, como no
    # Kanban interno. Os includes sao os que o cartao le - sem eles o quadro
    # dispara uma consulta por ticket.
    @tickets_by_column = tickets_scoped_by_company.operational
                                                   .where(ticket_column_id: @columns.select(:id))
                                                   .includes(*BOARD_INCLUDES)
                                                   .order(:position, :id)
                                                   .group_by(&:ticket_column_id)
  end

  def show; end

  # A abertura pelo cliente.
  #
  # Ele informa o PROBLEMA - categoria, assunto, descricao, arquivos. Para onde
  # o chamado vai e decisao de quem atende: o ticket entra em TRIAGEM e so anda
  # no Kanban depois de aprovado.
  #
  # Empresa e solicitante nao vem do formulario: sao os do contato logado,
  # gravados aqui. Mandar outro id no corpo nao muda nada - os campos sequer sao
  # lidos dos parametros.
  def create
    @ticket = build_ticket(categoria_escolhida)

    # A Categoria pode exigir anexo. A checagem e ANTES de gravar: um ticket
    # criado e so depois recusado deixaria lixo no Kanban da equipe.
    return render_missing_attachment if attachment_missing?

    # Ticket e anexos na MESMA transacao: o anexo so pode apontar para um ticket
    # que ja existe, e um ticket que exige anexo nao pode sobreviver sem ele.
    ActiveRecord::Base.transaction do
      @ticket.save!
      attach_uploaded_files!
    end

    render 'show', status: :created
  end

  private

  # O detalhe precisa do que as abas mostram; a listagem nao. Sobrescreve o
  # `fetch_ticket` da base apenas para pre-carregar - a FRONTEIRA continua
  # sendo a mesma `visible_tickets`.
  def fetch_ticket
    @ticket = visible_tickets.includes(*DETAIL_INCLUDES).find(params[:id])
  end

  # So o que o cliente pode decidir. Mesa, Estagio, prioridade, responsavel,
  # Empresa, solicitante, status e prazos ficam de fora da lista - nao e que
  # sejam ignorados depois: eles nunca chegam a ser lidos.
  def permitted_ticket_params
    params.permit(:title, :description)
  end

  # A Categoria e o unico rumo que o cliente da ao chamado, e ela pertence a uma
  # Mesa - e essa Mesa que recebe o chamado ate a triagem decidir. Sem categoria
  # informada, a primeira Mesa ativa segura o chamado: a triagem vai move-lo de
  # todo jeito.
  #
  # `client_visible` de proposito: e a MESMA consulta que monta o select dele.
  # Sem isso, a marcacao seria so enfeite de tela - um pedido montado a mao
  # escolheria qualquer Categoria de qualquer Mesa e definiria onde o chamado
  # entra. A fronteira e aqui, nao no formulario.
  def categoria_escolhida
    return if params[:ticket_category_id].blank?

    TicketCategory.client_visible
                  .joins(:team)
                  .where(teams: { account_id: Current.account.id, active: true, visible_in_portal: true })
                  .find_by(id: params[:ticket_category_id])
  end

  # As Mesas que atendem este cliente. Hoje, as ativas da conta: o cliente abre
  # chamado para a area que precisa, e o Kanban dele so mostra Mesa onde ele
  # tenha ticket.
  def client_teams
    Current.account.teams.active.visible_in_portal.order(:name)
  end

  # As Empresas do proprio contato - so aparecem para quem tem mais de uma (o
  # filtro do quadro so faz sentido quando ha o que filtrar).
  def client_companies
    Company.where(account_id: Current.account.id, id: current_contact.client_company_ids).order(:name)
  end

  # `visible_tickets` ja e' a fronteira; isto so ESTREITA para a Empresa
  # escolhida no seletor - nunca para uma fora de `client_company_ids`, que
  # `client_companies` garante de saida.
  def tickets_scoped_by_company
    return visible_tickets if params[:company_id].blank?

    empresa = client_companies.find_by(id: params[:company_id])
    empresa ? visible_tickets.where(company_id: empresa.id) : visible_tickets
  end

  def pick_team
    return client_teams.find_by(id: params[:team_id]) if params[:team_id].present?

    # Sem escolha explicita, a Mesa do ticket mais recente dele - e onde ele
    # estava olhando da ultima vez, sem precisar escolher nada.
    ultima = tickets_scoped_by_company.order(created_at: :desc).first&.team
    ultima || client_teams.first
  end

  # Onde o chamado do cliente entra: o Estagio "Pendente" da Mesa quando existe -
  # e o que a propria Mesa define como entrada -, senao o primeiro da fila.
  def entry_column(team)
    team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.order(:position, :id).first
  end

  # A Categoria e obrigatoria no ticket. Quando o cliente nao escolhe, a
  # primeira da Mesa responde por ela: a triagem interna reclassifica depois, e
  # isso e melhor do que barrar a abertura por uma escolha que e nossa.
  def default_category(team)
    # A marcada para o cliente primeiro: e a que quem administra escolheu como
    # porta de entrada. Sem nenhuma marcada, qualquer uma da Mesa serve - barrar
    # a abertura por uma escolha que e nossa seria pior.
    team.ticket_categories.client_visible.first ||
      team.ticket_categories.order(:position, :id).first
  end

  # O que o cliente escolheu, mais o que ele nao escolhe: Mesa de entrada,
  # Estagio, prioridade, Empresa e solicitante saem daqui, nunca dos parametros.
  #
  # A triagem manual (fila de Triagem) e' coisa de canal onde ninguem sabe
  # ainda quem e' o cliente (e-mail, por exemplo) - aqui o contato ja esta
  # AUTENTICADO como aquela Empresa, entao o Portal sempre roteia sozinho:
  # pela regra de prioridade da Empresa quando existir (`routing_rule_for`,
  # abaixo), senao pela Mesa da Categoria escolhida, como ja funcionava.
  def build_ticket(categoria)
    empresa = company_for_new_ticket
    regra = routing_rule_for(empresa)
    team = regra&.team || categoria&.team || client_teams.first
    # A regra de prioridade decide a MESA, nao a Categoria - uma Categoria de
    # outra Mesa nao pode sobreviver a troca (validacao
    # `ticket_category_belongs_to_team`), entao a entrada padrao da Mesa da
    # regra assume o lugar da escolha do cliente.
    categoria = nil if regra.present? && categoria&.team_id != team&.id

    ticket = Current.account.tickets.new(permitted_ticket_params)
    ticket.team = team
    ticket.ticket_column = entry_column(team)
    ticket.ticket_category = categoria || default_category(team)
    # Prioridade e obrigatoria no ticket, e deixou de ser escolha do cliente:
    # quem atende define depois. "Media" e o ponto de partida neutro.
    ticket.priority = 'medium'
    ticket.company_id = empresa
    ticket.contact_id = current_contact.id
    ticket.origin = 'client_area'
    # Sem fila de Triagem: o Portal ja roteia para a Mesa certa sozinho.
    ticket.pending_triage = false
    ticket
  end

  def routing_rule_for(company_id)
    return if company_id.blank?

    company = Company.find_by(id: company_id, account_id: Current.account.id)
    return if company.blank?

    Current.account.ticket_routing_rules.find_by(client_level: company.client_level)
  end

  # Os arquivos enviados junto do formulario. Multipart, porque o cliente manda
  # o print no mesmo gesto em que descreve o problema.
  def uploaded_files
    Array(params[:attachments]).reject(&:blank?)
  end

  def attachment_missing?
    @ticket.category_requires_attachment? && uploaded_files.empty?
  end

  def render_missing_attachment
    render json: { error: I18n.t('tickets.attachments.required_by_category'),
                   code: 'attachment_required' },
           status: :unprocessable_entity
  end

  def attach_uploaded_files!
    uploaded_files.each do |arquivo|
      anexo = @ticket.ticket_attachments.new(account_id: @ticket.account_id)
      anexo.file.attach(arquivo)
      anexo.save!
    end
  end

  # A empresa do ticket e a do contato. Com mais de uma, a primaria - a mesma
  # que o cadastro ja trata como principal.
  def company_for_new_ticket
    current_contact.company_id || current_contact.client_company_ids.first
  end
end
