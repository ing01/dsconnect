# Liga o push de "ticket filho concluido" (notification_type novo, ver
# app/models/notification.rb) para quem JA tinha uma NotificationSetting gravada.
# So' LIGA, nunca desliga nada que o agente tenha escolhido para outro tipo.
class EnableTicketChildCompletedPushForExistingAgents < ActiveRecord::Migration[7.2]
  def up
    NotificationSetting.find_each do |setting|
      next if setting.push_ticket_child_completed?

      setting.push_ticket_child_completed = true
      setting.save!
    end
  end

  def down
    NotificationSetting.find_each do |setting|
      next unless setting.push_ticket_child_completed?

      setting.push_ticket_child_completed = false
      setting.save!
    end
  end
end
