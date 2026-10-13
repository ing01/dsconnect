# ClientPushSubscription so' falava push de navegador (VAPID) ate agora - o
# app mobile do cliente final (ver plano do app Flutter) precisa de um
# segundo tipo, FCM, igual o NotificationSubscription do lado colaborador ja
# tem. Mesmos valores numericos do enum de la' (1/2), so' por consistencia -
# nao precisa bater, mas evita confundir os dois ao ler o banco direto.
#
# Default `browser_push` preserva o comportamento de toda inscricao ja
# existente (todas eram, implicitamente, push de navegador).
class AddSubscriptionTypeToClientPushSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :client_push_subscriptions, :subscription_type, :integer, default: 1, null: false
  end
end
