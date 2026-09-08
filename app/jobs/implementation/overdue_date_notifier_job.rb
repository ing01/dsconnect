# Varre projetos com data vencida e notifica o implantador responsável
# (fallback: o manager da Mesa) - porta o "sino de notificações" do painel.
# Roda uma vez por dia (config/schedule.yml); o dedup de "já notifiquei essa
# condição sem que tenha sido lida" fica no builder, não aqui.
class Implementation::OverdueDateNotifierJob < ApplicationJob
  queue_as :scheduled_jobs

  # Estágios antes do cliente entrar em acompanhamento - equivalente a
  # Novos/Integração do painel, onde vencer o `due_date` (prazo contratual)
  # é o alerta relevante.
  EARLY_STAGES = %w[pendente onboarding requisito em_andamento].freeze

  def perform
    Account.find_each do |account|
      notify_overdue_contract_ends(account)
      notify_overdue_support_ends(account)
    end
  end

  private

  def notify_overdue_contract_ends(account)
    account.projects.where(stage: EARLY_STAGES).where(due_date: ...Date.current).find_each do |project|
      Implementation::OverdueDateNotificationBuilder.new(project: project, notification_type: 'project_contract_end_overdue').perform
    end
  end

  def notify_overdue_support_ends(account)
    account.projects.where(stage: 'acompanhamento').where(support_ends_on: ...Date.current).find_each do |project|
      Implementation::OverdueDateNotificationBuilder.new(project: project, notification_type: 'project_support_end_overdue').perform
    end
  end
end
