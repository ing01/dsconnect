require 'rails_helper'

RSpec.describe 'Ticket Checklist Items API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:ticket) { create(:ticket, account: account) }

  describe 'POST .../checklist_items/attach_checklist' do
    it 'copies every item of the given Checklist onto the ticket' do
      checklist = create(:checklist, account: account, items: [{ 'title' => 'Confirmar dados' }, { 'title' => 'Instalar' }])

      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/checklist_items/attach_checklist",
           params: { checklist_id: checklist.id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.ticket_checklist_items.order(:position).pluck(:title)).to eq(['Confirmar dados', 'Instalar'])
    end

    it 'appends after items the ticket already has, instead of overwriting them' do
      ticket.ticket_checklist_items.create!(account: account, title: 'Já existente', position: 0)
      checklist = create(:checklist, account: account, items: [{ 'title' => 'Novo item' }])

      post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/checklist_items/attach_checklist",
           params: { checklist_id: checklist.id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(ticket.reload.ticket_checklist_items.order(:position).pluck(:title)).to eq(['Já existente', 'Novo item'])
    end

    it 'can be called more than once, attaching the same Checklist again' do
      checklist = create(:checklist, account: account, items: [{ 'title' => 'Item' }])

      2.times do
        post "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/checklist_items/attach_checklist",
             params: { checklist_id: checklist.id },
             headers: agent.create_new_auth_token,
             as: :json
      end

      expect(ticket.reload.ticket_checklist_items.count).to eq(2)
    end
  end
end
