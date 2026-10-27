class TriggerScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # trigger the scheduled campaign jobs
    Campaign.where(campaign_type: :one_off,
                   campaign_status: :active).where(scheduled_at: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |campaign|
      Campaigns::TriggerOneoffCampaignJob.perform_later(campaign)
    end

    # Job to reopen snoozed conversations
    Conversations::ReopenSnoozedConversationsJob.perform_later

    # Job to reopen snoozed notifications
    Notification::ReopenSnoozedNotificationsJob.perform_later

    # Job to auto-resolve conversations
    Account::ConversationsResolutionSchedulerJob.perform_later

    # Aviso/encerramento por inatividade do chat do Portal, por Fila
    Queues::InactivityJob.perform_later

    # Job to sync whatsapp templates
    Channels::Whatsapp::TemplatesSyncSchedulerJob.perform_later

    # Job to trigger pending executions
    AutomationRules::TriggerPendingExecutionsJob.perform_later

    # Varredura dos vencimentos de SLA dos Tickets. Reaproveita o mesmo cron de
    # 5 minutos que ja move o SLA das Conversations.
    Tickets::Sla::TriggerSweepJob.perform_later
  end
end

TriggerScheduledItemsJob.prepend_mod_with('TriggerScheduledItemsJob')
