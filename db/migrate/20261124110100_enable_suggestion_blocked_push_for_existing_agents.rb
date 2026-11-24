# Liga o push de "sugestao impedida" (notification_type novo, ver app/models/notification.rb)
# para quem JA tinha uma NotificationSetting gravada. So' LIGA, nunca desliga nada que o agente
# tenha escolhido para outro tipo. O aviso chega so' a quem abriu a sugestao.
class EnableSuggestionBlockedPushForExistingAgents < ActiveRecord::Migration[7.2]
  def up
    NotificationSetting.find_each do |setting|
      next if setting.push_suggestion_blocked?

      setting.push_suggestion_blocked = true
      setting.save!
    end
  end

  def down
    NotificationSetting.find_each do |setting|
      next unless setting.push_suggestion_blocked?

      setting.push_suggestion_blocked = false
      setting.save!
    end
  end
end
