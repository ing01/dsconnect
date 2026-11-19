require 'rails_helper'

RSpec.describe TicketCustomerNoticeRule do
  let(:account) { create(:account) }
  let(:dev_team) { create(:team, account: account, name: 'desenvolvimento') }
  let(:support_team) { create(:team, account: account, name: 'suporte') }
  let(:column) { create(:ticket_column, team: dev_team, name: 'Melhoria aprovada') }

  def build_rule(**attrs)
    described_class.new({ account: account, kind: 'stage', name: 'Aviso', body: 'Olá', ticket_column: column }.merge(attrs))
  end

  describe 'validations' do
    it 'requires a Estagio for a stage rule' do
      expect(build_rule(ticket_column: nil)).not_to be_valid
    end

    it 'requires the destination Mesa for a team rule' do
      expect(build_rule(kind: 'team', ticket_column: nil)).not_to be_valid
      expect(build_rule(kind: 'team', ticket_column: nil, team: support_team)).to be_valid
    end

    it 'requires a text and a known kind' do
      expect(build_rule(body: '')).not_to be_valid
      expect(build_rule(kind: 'other')).not_to be_valid
    end

    it 'refuses a Estagio or Mesa from another account' do
      foreign_team = create(:team, account: create(:account))

      expect(build_rule(kind: 'team', ticket_column: nil, team: foreign_team)).not_to be_valid
    end
  end

  describe '.matching' do
    let!(:stage_rule) { build_rule.tap(&:save!) }
    let!(:team_rule) { build_rule(kind: 'team', ticket_column: nil, team: support_team).tap(&:save!) }
    let!(:team_rule_from_dev) do
      build_rule(kind: 'team', ticket_column: nil, team: support_team, from_team: dev_team).tap(&:save!)
    end

    it 'finds the stage rule of the column the ticket entered' do
      found = described_class.matching(account_id: account.id, column_id: column.id)

      expect(found).to contain_exactly(stage_rule)
    end

    it 'finds team rules only when the Mesa changed, honouring the origin' do
      from_dev = described_class.matching(account_id: account.id, column_id: 0,
                                          from_team_id: dev_team.id, to_team_id: support_team.id)
      from_elsewhere = described_class.matching(account_id: account.id, column_id: 0,
                                                from_team_id: 999, to_team_id: support_team.id)

      expect(from_dev).to contain_exactly(team_rule, team_rule_from_dev)
      expect(from_elsewhere).to contain_exactly(team_rule)
    end

    it 'ignores inactive rules' do
      stage_rule.update!(active: false)

      expect(described_class.matching(account_id: account.id, column_id: column.id)).to be_empty
    end
  end

  describe '#render_body' do
    let(:company) { create(:company, account: account, name: 'Cantagallo') }
    let(:contact) { create(:contact, account: account, company: company, name: 'Renan') }
    let(:ticket) do
      create(:ticket, account: account, ticket_column: column, team: dev_team,
                      company: company, contact: contact, title: 'Relatório lento')
    end

    describe 'horas' do
      def text_with_hours(value)
        ticket.update!(custom_attributes: { 'estimativa_original_horas' => value }) unless value == :none
        build_rule(body: 'Estimativa: {{horas}}h.').render_body(ticket)
      end

      it 'sends the estimate as the number only, in the format of the screen' do
        expect(text_with_hours(6)).to eq('Estimativa: 6h.')
        expect(text_with_hours(2.5)).to eq('Estimativa: 2,5h.')
        expect(text_with_hours('1,25')).to eq('Estimativa: 1,25h.')
      end

      it 'leaves it blank when the ticket has no estimate' do
        expect(text_with_hours(:none)).to eq('Estimativa: h.')
        expect(text_with_hours(0)).to eq('Estimativa: h.')
      end

      it 'is one of the variables offered on the settings screen' do
        expect(described_class::VARIABLES).to include('horas' => 'Horas estimadas')
      end
    end

    it 'replaces the variables with the ticket data' do
      rule = build_rule(body: 'Olá {{solicitante}}, o ticket #{{numero}} ({{titulo}}) de {{cliente}} ' \
                              'está em {{estagio}}, na Mesa {{mesa}}. Antes: {{mesa_anterior}}.')

      text = rule.render_body(ticket, previous_team: support_team)

      expect(text).to eq("Olá Renan, o ticket ##{ticket.display_id} (Relatório lento) de Cantagallo " \
                         'está em Melhoria aprovada, na Mesa Desenvolvimento. Antes: Suporte.')
    end

    it 'keeps an unknown variable as written' do
      expect(build_rule(body: 'Oi {{inexistente}}').render_body(ticket)).to eq('Oi {{inexistente}}')
    end
  end
end
