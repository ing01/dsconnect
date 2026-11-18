require 'rails_helper'
require 'roo'

# A planilha completa da Busca detalhada: TUDO o que o ticket guarda, uma coluna
# para cada, e vazio quando nao esta preenchido.
RSpec.describe Tickets::Export::FullSheet do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account, name: 'desenvolvimento') }
  let(:column) { create(:ticket_column, team: team, name: 'Em andamento') }
  let(:category) { create(:ticket_category, team: team, name: 'Categoria de teste') }
  let(:user) { create(:user, account: account, role: :agent, name: 'Ana Souza') }
  let(:sheet) { described_class.new(account: account) }

  def reload_with_includes(ticket)
    Ticket.includes(*described_class::INCLUDES).find(ticket.id)
  end

  def cell(ticket, label)
    index = described_class.headers.index(label)
    raise "coluna inexistente: #{label}" if index.nil?

    sheet.row(reload_with_includes(ticket))[index]
  end

  it 'has one unique label per column' do
    headers = described_class.headers

    expect(headers).to eq(headers.uniq)
    expect(headers.size).to be > 80
  end

  it 'covers every column of the tickets table (nothing is missing)' do
    # Colunas internas que nao sao dado do ticket (chaves de ordenacao e de ligacao ja
    # cobertas por outra coluna com nome legivel).
    covered_by_name = {
      'id' => 'ID interno', 'display_id' => 'Número', 'title' => 'Título', 'description' => 'Descrição',
      'observation' => 'Observação', 'resolution' => 'Resolução', 'status' => 'Status', 'priority' => 'Prioridade',
      'team_id' => 'Mesa de Serviço', 'ticket_column_id' => 'Estágio', 'ticket_category_id' => 'Categoria',
      'ticket_complexity_id' => 'Complexidade', 'service_catalog_item_id' => 'Catálogo de serviços',
      'company_id' => 'Empresa', 'contact_id' => 'Solicitante', 'assignee_id' => 'Atendente',
      'assignee_2_id' => 'Responsável nível 2', 'assignee_3_id' => 'Responsável nível 3',
      'assignee_4_id' => 'Responsável nível 4', 'assignee_5_id' => 'Responsável nível 5',
      'parent_id' => 'Ticket pai', 'merged_into_id' => 'Agrupado em', 'project_id' => 'Projeto',
      'project_task_template_id' => 'Tarefa do projeto', 'sprint_id' => 'Sprint',
      'development_type' => 'Tipo de desenvolvimento', 'jira_key' => 'Chave do Jira',
      'next_project_stage' => 'Próxima etapa do projeto', 'pending_triage' => 'Aguardando triagem',
      'triaged_at' => 'Triado em', 'triaged_by_id' => 'Triado por', 'blocked_at' => 'Impedido em',
      'blocked_reason' => 'Motivo do impedimento', 'blocked_by_id' => 'Impedido por',
      'blocked_by_child_id' => 'Impedimento vindo do filho', 'child_completed_at' => 'Filho concluído (selo)',
      'created_at' => 'Criado em', 'updated_at' => 'Atualizado em', 'due_date' => 'Data de entrega',
      'scheduled_at' => 'Agendado para', 'resolved_at' => 'Resolvido em', 'closed_at' => 'Fechado em',
      'cancelled_at' => 'Cancelado em', 'close_reason' => 'Motivo do cancelamento',
      'custom_attributes' => 'Outros campos personalizados'
    }
    # `account_id` e' a propria conta (todas as linhas); `position` e' a ordem no quadro;
    # `child_completed_display_id` e' so' o numero do filho do selo.
    ignored = %w[account_id position child_completed_display_id]

    missing = Ticket.column_names - ignored - covered_by_name.keys
    expect(missing).to be_empty, "colunas do ticket sem coluna na planilha: #{missing.join(', ')}"
    expect(described_class.headers).to include(*covered_by_name.values)
  end

  context 'with a ticket that has everything filled in' do
    let(:company) do
      create(:company, account: account, name: 'Cantagallo', legal_name: 'Cantagallo Ltda', cnpj: '11222333000181',
                       codigo: 'C-9', classification_level: 4)
    end
    let(:contact) { create(:contact, account: account, company: company, name: 'Renan', email: 'renan@empresa.com', phone_number: '+5511999990000') }
    let(:parent) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }
    let(:ticket) do
      create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category,
                      title: 'Relatório lento', description: 'Demora para abrir', observation: 'Cliente pediu retorno',
                      priority: :high, company: company, contact: contact, assignee: user, parent: parent,
                      jira_key: 'DM-12', development_type: :bug,
                      custom_attributes: { 'observacoes_dev' => 'Ajustar índice', 'extra' => 'valor' })
    end

    before do
      ticket.update!(due_date: Time.zone.parse('2026-12-01 10:00'))
      ticket.ticket_time_entries.create!(account_id: account.id, user: user, hours: 1.5, worked_on: Date.new(2026, 11, 10),
                                         category: 'desenvolvimento', note: 'Investigação')
      ticket.ticket_comments.create!(account_id: account.id, user: user, content: 'Primeiro comentário')
    end

    it 'exports the registration data, the people and the dates', :aggregate_failures do
      expect(cell(ticket, 'Título')).to eq('Relatório lento')
      expect(cell(ticket, 'Descrição')).to eq('Demora para abrir')
      expect(cell(ticket, 'Observação')).to eq('Cliente pediu retorno')
      expect(cell(ticket, 'Prioridade')).to be_present
      expect(cell(ticket, 'Mesa de Serviço')).to eq('Desenvolvimento')
      expect(cell(ticket, 'Estágio')).to eq('Em andamento')
      expect(cell(ticket, 'Categoria')).to eq('Categoria de teste')
      expect(cell(ticket, 'Empresa')).to eq('Cantagallo')
      expect(cell(ticket, 'Razão social')).to eq('Cantagallo Ltda')
      expect(cell(ticket, 'CNPJ')).to eq('11222333000181')
      expect(cell(ticket, 'Nível da empresa')).to eq(4)
      expect(cell(ticket, 'Solicitante')).to eq('Renan')
      expect(cell(ticket, 'E-mail do solicitante')).to eq('renan@empresa.com')
      expect(cell(ticket, 'Atendente')).to eq('Ana Souza')
      expect(cell(ticket, 'Ticket pai')).to eq("##{parent.display_id}")
      expect(cell(ticket, 'Chave do Jira')).to eq('DM-12')
      expect(cell(ticket, 'Tipo de desenvolvimento')).to eq('Bug')
      expect(cell(ticket, 'Data de entrega')).to eq('01/12/2026 10:00')
    end

    it 'exports the development fields and the remaining custom attributes' do
      expect(cell(ticket, 'Observações do desenvolvedor')).to eq('Ajustar índice')
      expect(cell(ticket, 'Outros campos personalizados')).to eq('extra: valor')
    end

    it 'exports what is linked to the ticket' do
      expect(cell(ticket, 'Apontamentos (quantidade)')).to eq(1)
      expect(cell(ticket, 'Horas apontadas')).to eq(1.5)
      expect(cell(ticket, 'Apontamentos')).to include('Ana Souza', '1.5h', 'Investigação')
      expect(cell(ticket, 'Comentários internos (quantidade)')).to eq(1)
      expect(cell(ticket, 'Comentários internos')).to include('Primeiro comentário', 'Ana Souza')
      expect(cell(ticket, 'Histórico (quantidade)')).to be >= 1
      expect(cell(parent, 'Tickets filhos')).to eq("##{ticket.display_id}")
    end

    it 'exports the impediment' do
      ticket.block!(user, reason: 'Aguardando fornecedor')

      expect(cell(ticket, 'Impedido')).to eq('Sim')
      expect(cell(ticket, 'Impedido por')).to eq('Ana Souza')
      expect(cell(ticket, 'Motivo do impedimento')).to eq('Aguardando fornecedor')
      expect(cell(parent, 'Impedido')).to eq('Sim')
      expect(cell(parent, 'Impedimento vindo do filho')).to eq("##{ticket.display_id}")
    end
  end

  context 'with a bare ticket' do
    let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category) }

    it 'leaves everything that is not filled in empty, without failing' do
      row = sheet.row(reload_with_includes(ticket))

      expect(row.size).to eq(described_class.headers.size)
      ['Observação', 'Resolução', 'Empresa', 'Solicitante', 'Atendente', 'Seguidores', 'Anexos', 'Comentários internos',
       'Motivo do impedimento', 'Fechado em', 'Chave do Jira', 'Sprint', 'Projeto'].each do |label|
        expect(cell(ticket, label)).to be_nil, "#{label} deveria estar vazio"
      end
      expect(cell(ticket, 'Impedido')).to eq('Não')
      expect(cell(ticket, 'Anexos (quantidade)')).to eq(0)
    end
  end

  it 'cuts a text above the Excel cell limit instead of corrupting the file' do
    ticket = create(:ticket, account: account, ticket_column: column, team: team, ticket_category: category,
                             description: 'a' * 40_000)

    value = cell(ticket, 'Descrição')

    expect(value.length).to be < 33_000
    expect(value).to include('texto cortado')
  end
end
