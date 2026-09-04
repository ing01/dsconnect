require 'rails_helper'

RSpec.describe 'Project Modules API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:template_a) { create(:project_task_template, account: account) }
  let(:template_b) { create(:project_task_template, account: account) }

  describe 'POST .../project_modules' do
    it 'creates a module and syncs its task templates in order' do
      post "/api/v1/accounts/#{account.id}/project_modules",
           params: {
             project_module: { name: 'Onboarding padrão' },
             task_template_ids: [template_b.id, template_a.id]
           },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Onboarding padrão')
      expect(response.parsed_body['task_templates'].pluck('id')).to eq([template_b.id, template_a.id])
    end
  end

  describe 'PATCH .../project_modules/:id' do
    it 'clears every task template when task_template_ids is sent empty' do
      project_module = create(:project_module, account: account)
      project_module.project_module_task_templates.create!(project_task_template: template_a, position: 0)

      patch "/api/v1/accounts/#{account.id}/project_modules/#{project_module.id}",
            params: { project_module: { name: project_module.name }, task_template_ids: [] },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(project_module.reload.project_task_templates).to be_empty
    end

    it 'is forbidden for an agent' do
      project_module = create(:project_module, account: account)

      patch "/api/v1/accounts/#{account.id}/project_modules/#{project_module.id}",
            params: { project_module: { name: 'Novo nome' } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
