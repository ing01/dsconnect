# Liga o push de "resposta do cliente no ticket" (notification_type novo,
# ver app/models/notification.rb) para quem JA tinha uma NotificationSetting
# gravada - sem isto, o tipo só nasceria ligado por padrão para agente NOVO
# (ver AccountUser#create_notification_setting), e quem ja existe na conta
# nunca saberia que a opcao existe.
#
# So' LIGA - nunca desliga nada que o agente ja tenha escolhido para outro
# tipo (o flag e' por bit, cada `push_flags=` aqui so' afeta este bit).
class EnableTicketCustomerCommunicationPushForExistingAgents < ActiveRecord::Migration[7.2]
  def up
    NotificationSetting.find_each do |setting|
      next if setting.push_ticket_customer_communication_received?

      setting.push_ticket_customer_communication_received = true
      setting.save!
    end
  end

  def down
    NotificationSetting.find_each do |setting|
      next unless setting.push_ticket_customer_communication_received?

      setting.push_ticket_customer_communication_received = false
      setting.save!
    end
  end
end
