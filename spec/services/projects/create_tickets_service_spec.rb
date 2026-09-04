require 'rails_helper'

RSpec.describe Projects::CreateTicketsService do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:project) { create(:project, account: account, team: team) }
  let(:template) do
    create(
      :project_task_template, account: account, name: 'Treinamento',
                               default_ticket_title: 'Treinamento do cliente',
                               due_days: 5, next_project_stage: 'acompanhamento',
                               checklist: [{ 'title' => 'Confirmar presença' }]
    )
  end

  def perform(tasks)
    described_class.new(account: account, project: project, tasks: tasks, user: nil).perform
  end

  it "lands new tickets on the Mesa's Pendente column, not just the first by position" do
    # The Mesa's own default provisioning already puts Pendente first, so
    # reorder it to the end to prove the service targets it by `kind`.
    pending_column = team.ticket_columns.find_by!(kind: 'pending')
    other_column = team.ticket_columns.find_by!(kind: 'normal')
    pending_column.update!(position: 5)
    other_column.update!(position: 0)

    tickets = perform([{ task_template_id: template.id }])

    expect(tickets.first.ticket_column).to eq(pending_column)
  end

  it 'falls back to the first column by position when the Mesa has no Pendente column' do
    team.ticket_columns.where(kind: 'pending').destroy_all
    first_column = team.ticket_columns.order(:position).first

    tickets = perform([{ task_template_id: template.id }])

    expect(tickets.first.ticket_column).to eq(first_column)
  end

  it 'copies the template checklist onto the generated ticket' do
    tickets = perform([{ task_template_id: template.id }])

    expect(tickets.first.ticket_checklist_items.pluck(:title)).to eq(['Confirmar presença'])
  end

  it 'carries the next_project_stage from the template' do
    tickets = perform([{ task_template_id: template.id }])

    expect(tickets.first.next_project_stage).to eq('acompanhamento')
  end

  it 'defaults the due date from due_days when none is given' do
    tickets = perform([{ task_template_id: template.id }])

    expect(tickets.first.due_date.to_date).to eq(Time.zone.now.to_date + 5.days)
  end
end
