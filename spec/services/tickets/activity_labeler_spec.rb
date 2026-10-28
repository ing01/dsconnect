require 'rails_helper'

RSpec.describe Tickets::ActivityLabeler do
  let(:account) { create(:account) }
  let(:ticket) { create(:ticket, account: account) }
  let(:fernando) { create(:user, name: 'Fernando') }
  let(:joao) { create(:user, name: 'João Vitor') }

  def activity(type, **attributes)
    create(:ticket_activity, ticket: ticket, account: account, activity_type: type, **attributes)
  end

  def labels(record)
    described_class.new([record]).labels_for(record)
  end

  it 'shows the agents names instead of their ids when the assignee changes' do
    record = activity(:assignee_changed, previous_value: fernando.id.to_s, new_value: joao.id.to_s)

    expect(labels(record)).to include(previous_label: 'Fernando', new_label: 'João Vitor')
  end

  it 'translates the priority' do
    record = activity(:priority_changed, previous_value: 'low', new_value: 'urgent')

    expect(labels(record)).to include(previous_label: 'Baixa', new_label: 'Urgente')
  end

  it 'resolves the Mesa and the Estagio' do
    record = activity(:column_changed, previous_value: ticket.ticket_column_id.to_s)

    expect(labels(record)[:previous_label]).to eq(ticket.ticket_column.name)
  end

  it 'leaves the label empty when the record no longer exists, so the stored value is shown' do
    record = activity(:assignee_changed, new_value: '0')

    expect(labels(record)[:new_label]).to eq('0')
  end

  it 'lists every before/after pair of a transfer with names' do
    record = activity(:transferred, meta: { changes: {
                        'assignee_id' => [fernando.id, joao.id], 'priority' => %w[low high]
                      } })

    expect(labels(record)[:details]).to contain_exactly(
      { label: 'Responsável', previous: 'Fernando', new: 'João Vitor' },
      { label: 'Prioridade', previous: 'Baixa', new: 'Alta' }
    )
  end

  it 'formats dates' do
    record = activity(:due_date_changed, new_value: '2026-10-28T14:30:00Z')

    expect(labels(record)[:new_label]).to match(%r{\A\d{2}/10/2026 \d{2}:30\z})
  end

  it 'names the owner of a follower or an attachment through meta.details' do
    record = activity(:attachment_added, meta: { details: { 'Arquivo' => 'nota.pdf' } })

    expect(labels(record)[:details]).to eq([{ label: 'Arquivo', previous: nil, new: 'nota.pdf' }])
  end
end

RSpec.describe Ticket, 'history of changes' do
  let(:account) { create(:account) }
  let(:ticket) { create(:ticket, account: account) }

  it 'logs due date and description changes' do
    ticket.update!(due_date: Time.zone.parse('2026-11-01 10:00'), description: 'Nova descrição')

    types = ticket.ticket_activities.pluck(:activity_type)
    expect(types).to include('due_date_changed', 'description_changed')
  end
end
