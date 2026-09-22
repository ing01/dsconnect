require 'rails_helper'

# Quantos niveis a Mesa usa e configuracao, e nao codigo. O que se prova aqui e
# que subir uma Mesa para tres niveis basta - que o Nivel 3 tem lugar proprio no
# ticket, que a Mesa que atende em dois o recusa, e que a permissao por nivel
# continua valendo em todos eles.
RSpec.describe AssigneeLeveled do
  let(:account) { create(:account) }
  let(:n1) { create(:user, account: account, role: :agent) }
  let(:n2) { create(:user, account: account, role: :agent) }
  let(:n3) { create(:user, account: account, role: :agent) }

  # Uma Mesa com niveis e os membros habilitados em cada um.
  def mesa_com_niveis(count, habilitacoes)
    team = create(:team, account: account, assignee_levels_enabled: true, assignee_levels_count: count)
    team.add_members(habilitacoes.keys.map(&:id))
    habilitacoes.each do |user, levels|
      team.team_members.find_by(user_id: user.id).update!(levels: levels)
    end
    team
  end

  def ticket_da(team)
    create(:ticket, account: account, team: team, ticket_column: create(:ticket_column, team: team, position: 0))
  end

  describe 'AssigneeLeveled.assignee_column' do
    # O defeito que motivou a mudanca: o mapeamento antigo era um ternario, e
    # TODO nivel diferente de 1 caia em `assignee_2_id`. Com tres niveis, o
    # Nivel 3 gravaria em cima do Nivel 2 - sem erro nenhum.
    it 'gives each level its own column' do
      colunas = described_class::ALL_LEVELS.map { |level| described_class.assignee_column(level) }

      expect(colunas).to eq(%i[assignee_id assignee_2_id assignee_3_id assignee_4_id assignee_5_id])
      expect(colunas.uniq.size).to eq(colunas.size)
    end

    it 'keeps level 1 on the assignee_id that everything else already uses' do
      expect(described_class.assignee_column(1)).to eq(:assignee_id)
    end
  end

  describe 'Team#assignee_levels' do
    it 'lists the levels the desk actually uses' do
      expect(mesa_com_niveis(3, {}).assignee_levels).to eq([1, 2, 3])
    end

    # Sem a configuracao ligada a Mesa tem o responsavel unico de sempre - que e
    # o Nivel 1 -, para quem percorre os niveis funcionar nos dois casos.
    it 'reports a single level when the desk does not use levels' do
      expect(create(:team, account: account).assignee_levels).to eq([1])
    end

    it 'refuses a count the ticket has no column for' do
      team = create(:team, account: account, assignee_levels_enabled: true)

      expect(team.update(assignee_levels_count: AssigneeLeveled::MAX_LEVEL + 1)).to be(false)
      expect(team.update(assignee_levels_count: 1)).to be(false)
      expect(team.update(assignee_levels_count: AssigneeLeveled::MAX_LEVEL)).to be(true)
    end
  end

  describe 'atribuir um responsavel por nivel' do
    it 'stores the third-level assignee without overwriting the second' do
      team = mesa_com_niveis(3, { n1 => [1], n2 => [2], n3 => [3] })
      ticket = ticket_da(team)

      ticket.update!(assignee_id: n1.id, assignee_2_id: n2.id, assignee_3_id: n3.id)
      ticket.reload

      expect(ticket.assignee_for_level(1)).to eq(n1)
      expect(ticket.assignee_for_level(2)).to eq(n2)
      expect(ticket.assignee_for_level(3)).to eq(n3)
    end

    # O nivel e da participacao na Mesa: quem nao foi habilitado nele nao ocupa,
    # e a regra vale no registro para valer tambem na API.
    it 'refuses someone not enabled for that level' do
      team = mesa_com_niveis(3, { n1 => [1], n3 => [3] })
      ticket = ticket_da(team)

      expect(ticket.update(assignee_3_id: n1.id)).to be(false)
      expect(ticket.errors[:assignee_3_id]).to be_present
    end

    it 'refuses a level beyond what the desk uses' do
      team = mesa_com_niveis(2, { n1 => [1], n2 => [2] })
      ticket = ticket_da(team)

      expect(ticket.update(assignee_3_id: n2.id)).to be(false)
      expect(ticket.errors[:assignee_3_id].join).to include('2')
    end

    it 'refuses any level on a desk that does not use levels' do
      team = create(:team, account: account)
      team.add_members([n2.id])
      ticket = ticket_da(team)

      expect(ticket.update(assignee_2_id: n2.id)).to be(false)
      expect(ticket.errors[:assignee_2_id].join)
        .to eq(I18n.t('tickets.assignee_levels.not_enabled'))
    end

    # A regressao que este projeto ja pagou uma vez: validar o nivel a cada
    # salvamento tornava um ticket antigo impossivel de fechar, cancelar,
    # transferir ou impedir - por um dado que ninguem estava tocando.
    it 'does not block saving a ticket whose old assignee was never enabled' do
      team = mesa_com_niveis(3, { n1 => [1] })
      ticket = ticket_da(team)
      ticket.update!(assignee_id: n1.id)
      team.team_members.find_by(user_id: n1.id).update!(levels: [])

      expect(ticket.reload.update(title: 'Outro titulo')).to be(true)
    end
  end

  describe 'Ticket#level_of' do
    it 'finds the level a person answers for on this ticket' do
      team = mesa_com_niveis(3, { n1 => [1], n2 => [2], n3 => [3] })
      ticket = ticket_da(team)
      ticket.update!(assignee_id: n1.id, assignee_2_id: n2.id, assignee_3_id: n3.id)

      expect(ticket.level_of(n3.id)).to eq(3)
      expect(ticket.level_of(create(:user, account: account).id)).to be_nil
    end
  end

  describe 'apontamento de horas' do
    it 'accepts a third level and summarises hours for every level of the desk' do
      team = mesa_com_niveis(3, { n1 => [1], n3 => [3] })
      ticket = ticket_da(team)
      ticket.update!(assignee_id: n1.id, assignee_3_id: n3.id)

      ticket.ticket_time_entries.create!(account: account, user: n3, hours: 2.5,
                                         category: 'desenvolvimento', worked_on: Time.zone.today)

      resumo = ticket.reload.hours_by_level
      expect(resumo.keys).to eq([1, 2, 3])
      expect(resumo[3][:hours]).to eq(2.5)
      expect(resumo[3][:assignee]).to eq(n3)
    end
  end
end
