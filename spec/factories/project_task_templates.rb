FactoryBot.define do
  factory :project_task_template do
    sequence(:name) { |n| "Tarefa #{n}" }
    default_ticket_title { 'Chamado padrão' }
    due_days { 3 }
    account
  end
end
