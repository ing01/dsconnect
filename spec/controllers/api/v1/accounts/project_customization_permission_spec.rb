require 'rails_helper'

# Modulos e Tarefas (modelos de tarefa) sao personalizados pelo administrador e por quem tem o
# perfil de acesso de implantacao (`project_manage`). Um agente comum nao.
RSpec.describe 'Project customization permission', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:implementer) do
    user = create(:user, account: account, role: :agent)
    role = create(:custom_role, account: account, permissions: ['project_manage'])
    account.account_users.find_by(user_id: user.id).update!(custom_role: role)
    user
  end

  def create_module(user)
    post "/api/v1/accounts/#{account.id}/project_modules",
         params: { project_module: { name: 'Onboarding' } }, headers: user.create_new_auth_token, as: :json
  end

  def create_task(user)
    post "/api/v1/accounts/#{account.id}/project_task_templates",
         params: { project_task_template: { name: 'Treinar equipe', default_ticket_title: 'Treinar equipe' } },
         headers: user.create_new_auth_token, as: :json
  end

  it 'lets the implementation profile create modules and tasks' do
    create_module(implementer)
    expect(response).to have_http_status(:success)

    create_task(implementer)
    expect(response).to have_http_status(:success)
  end

  it 'keeps a plain agent out' do
    create_module(agent)
    expect(response).to have_http_status(:unauthorized)

    create_task(agent)
    expect(response).to have_http_status(:unauthorized)
  end
end
