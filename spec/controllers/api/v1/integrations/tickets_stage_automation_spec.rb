require 'rails_helper'

# Mudar o Estagio de um ticket pela API de Integracao tem de rodar tudo o que o
# Estagio de destino configurou - a Automacao de Estagio (ex.: Finalizado muda o
# status) e as Mensagens ao cliente -, do mesmo jeito que arrastar o card no
# Kanban.
RSpec.describe 'Ticket Integration API - Estagio e automacoes', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:dev_team) { create(:team, account: account, name: 'desenvolvimento') }
  let(:origin) { create(:ticket_column, team: dev_team, name: 'Em desenvolvimento') }
  let(:finished) do
    create(:ticket_column, team: dev_team, name: 'Finalizado dev', automations_enabled: true,
                           automation_actions: [{ 'type' => 'set_status', 'value' => 'closed' }])
  end
  let(:ticket) { create(:ticket, account: account, ticket_column: origin, team: dev_team) }

  def move_to(column, extra = {})
    patch "/api/v1/integrations/tickets/#{ticket.id}",
          params: { ticket_column_id: column.id }.merge(extra), headers: headers, as: :json
  end

  it 'runs the automation of the destination Estagio (status becomes closed)' do
    perform_enqueued_jobs { move_to(finished) }

    expect(response).to have_http_status(:success)
    expect(ticket.reload.status).to eq('closed')
    # Fechar tambem leva o ticket para o Finalizado da Mesa.
    expect(ticket.ticket_column.kind).to eq('completed')
  end

  it 'still runs it when other fields change in the same request' do
    perform_enqueued_jobs { move_to(finished, priority: 'urgent', custom_attributes: { 'origem' => 'jira' }) }

    expect(ticket.reload.status).to eq('closed')
    expect(ticket.priority).to eq('urgent')
  end

  it 'does not run it when the Estagio does not change' do
    perform_enqueued_jobs { move_to(origin, priority: 'urgent') }

    expect(ticket.reload.status).to eq('open')
  end

  it 'sends the customer message configured for the Estagio' do
    contact = create(:contact, account: account, email: 'cliente@empresa.com')
    ticket.update!(contact: contact)
    TicketCustomerNoticeRule.create!(account: account, kind: 'stage', name: 'Finalizou', body: 'Ticket {{numero}} finalizado',
                                     ticket_column: finished)

    expect { move_to(finished) }.to have_enqueued_job(Tickets::CustomerNoticeJob).with(ticket.id, finished.id, nil, nil)
  end

  it 'closing the child through the Estagio notifies the parent' do
    parent = create(:ticket, account: account, ticket_column: origin, team: dev_team,
                             assignee: create(:user, account: account, role: :agent))
    ticket.update!(parent: parent)
    dev_team.update!(development_module_enabled: true)

    perform_enqueued_jobs { move_to(finished) }

    expect(parent.reload.child_completed_display_id).to eq(ticket.display_id)
  end
end
