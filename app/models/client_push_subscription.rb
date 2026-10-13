# A inscricao de push de um Contato do Portal do Cliente - o mesmo mecanismo
# de `NotificationSubscription`, so que dono e' um Contact, e nao um User.
# Existe separada porque aquela e' `belongs_to :user` e nao aceitaria um
# Contact sem reabrir o model inteiro.
#
# Dois tipos, igual o lado colaborador: `browser_push` (VAPID, o navegador do
# Portal) e `fcm` (o app mobile do cliente final).
class ClientPushSubscription < ApplicationRecord
  belongs_to :account
  belongs_to :contact

  SUBSCRIPTION_TYPES = {
    browser_push: 1,
    fcm: 2
  }.freeze

  enum subscription_type: SUBSCRIPTION_TYPES
end
