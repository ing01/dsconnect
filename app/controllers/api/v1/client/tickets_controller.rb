# Os tickets na Area do Cliente: a lista, o detalhe e a abertura.
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

  # A lista. Todas as Mesas do cliente juntas, e nao uma por vez - o cartao de
  # cada chamado traz a Mesa e o Estagio (`team_name`/`ticket_column_name`,
  # no partial) para dizer onde ele esta, ja que o board deixou de recortar
  # por Mesa.
  def index
    @companies = client_companies
    # `operational`: resolvido, fechado e cancelado saem da lista, como no
    # Kanban interno. Opcoes de filtro vem de TODOS os chamados operacionais
    # do cliente, nao so dos que sobrevivem aos filtros ja aplicados - senao
    # escolher uma Mesa faria o filtro de Estagio esquecer as opcoes das
    # outras Mesas.
    base = visible_tickets.operational
    @teams = filter_options(base, :team, 'teams')
    @ticket_columns = filter_options(base, :ticket_column, 'ticket_columns')
    @assignees = filter_options(base, :assignee, 'users')

    relation = tickets_scoped_by_number(tickets_scoped_by_company(base))
    relation = tickets_scoped_by_team(relation)
    relation = tickets_scoped_by_column(relation)
    relation = tickets_scoped_by_assignee(relation)
    relation = tickets_scoped_by_date(relation)
    # Os includes sao os que o cartao le - sem eles a lista dispara uma
    # consulta por ticket.
    @tickets = relation.includes(*BOARD_INCLUDES).order(created_at: :desc)
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

  # As Mesas que atendem este cliente. Hoje, as ativas da conta - usada so na
  # abertura de um chamado novo (entrada padrao quando a Categoria nao decide
  # a Mesa); a lista de chamados nao recorta mais por Mesa.
  def client_teams
    Current.account.teams.active.visible_in_portal.order(:name)
  end

  # As Empresas do proprio contato - so aparecem para quem tem mais de uma (o
  # filtro do quadro so faz sentido quando ha o que filtrar).
  def client_companies
    Company.where(account_id: Current.account.id, id: current_contact.client_company_ids).order(:name)
  end

  # `relation` ja e' a fronteira; isto so ESTREITA para a Empresa escolhida no
  # seletor - nunca para uma fora de `client_company_ids`, que `client_companies`
  # garante de saida.
  def tickets_scoped_by_company(relation)
    return relation if params[:company_id].blank?

    empresa = client_companies.find_by(id: params[:company_id])
    empresa ? relation.where(company_id: empresa.id) : relation
  end

  # Busca pelo numero do chamado (`display_id`) - parcial, porque o cliente
  # pode nao lembrar o numero inteiro. So estreita quando o parametro vem
  # preenchido, nunca troca a fronteira de `visible_tickets`.
  def tickets_scoped_by_number(relation)
    # Aceita digitar com ou sem o `#` (o cartao mostra "#42") - sem tirar o
    # prefixo, buscar "#42" nunca bateria com nada.
    query = params[:q].to_s.strip.delete_prefix('#')
    return relation if query.blank?

    relation.where('CAST(tickets.display_id AS TEXT) LIKE ?', "%#{query}%")
  end

  def tickets_scoped_by_team(relation)
    return relation if params[:team_id].blank?

    relation.where(team_id: params[:team_id])
  end

  def tickets_scoped_by_column(relation)
    return relation if params[:ticket_column_id].blank?

    relation.where(ticket_column_id: params[:ticket_column_id])
  end

  def tickets_scoped_by_assignee(relation)
    return relation if params[:assignee_id].blank?

    relation.where(assignee_id: params[:assignee_id])
  end

  # `created_after`/`created_before` sao datas soltas ("YYYY-MM-DD"); o limite
  # de cima vai ate o fim do dia, senao um chamado aberto a tarde no ultimo dia
  # do periodo ficaria de fora (a data pura vira meia-noite na comparacao).
  def tickets_scoped_by_date(relation)
    relation = relation.where('tickets.created_at >= ?', params[:created_after].to_date.beginning_of_day) if params[:created_after].present?
    relation = relation.where('tickets.created_at <= ?', params[:created_before].to_date.end_of_day) if params[:created_before].present?
    relation
  end

  # Opcoes pro seletor de um filtro - so os valores que aparecem de verdade
  # entre os chamados que o cliente pode ver, nunca a lista inteira da conta
  # (uma Mesa ou um agente sem nenhum chamado deste cliente nao e' uma opcao
  # util, e exporia estrutura interna sem necessidade).
  def filter_options(relation, association, table)
    relation.joins(association).distinct.pluck("#{table}.id", "#{table}.name").map { |id, name| { id: id, name: name } }
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
  # A Mesa/Estagio calculados aqui sao so a ENTRADA SUGERIDA - o chamado fica
  # em `pending_triage` ate um agente aprovar (ver `TicketTriage#approve_triage!`),
  # e so entao passa a valer no Kanban da equipe. A regra de roteamento por
  # Empresa (`routing_rule_for`, abaixo) decide essa sugestao quando existe,
  # senao a Mesa da Categoria escolhida - do jeito que ja funcionava -, mas em
  # nenhum dos dois casos isso dispensa a aprovacao manual.
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
    # Todo chamado do Portal (app ou navegador) entra em Triagem - so' vai
    # para o Kanban da equipe depois que um agente aprovar.
    ticket.pending_triage = true
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
