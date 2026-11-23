# Liga o push de "impedimento removido" (notification_type novo, ver app/models/notification.rb)
# para quem JA tinha uma NotificationSetting gravada. So' LIGA, nunca desliga nada que o agente
# tenha escolhido para outro tipo.
class EnableTicketImpedimentReleasedPushForExistingAgents < ActiveRecord::Migration[7.2]
  def up
    NotificationSetting.find_each do |setting|
      next if setting.push_ticket_impediment_released?

      setting.push_ticket_impediment_released = true
      setting.save!
    end
  end

  def down
    NotificationSetting.find_each do |setting|
      next unless setting.push_ticket_impediment_released?

      setting.push_ticket_impediment_released = false
      setting.save!
    end
  end
end
