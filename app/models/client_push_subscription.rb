# A inscricao de push (VAPID) de um Contato do Portal do Cliente - o mesmo
# mecanismo de `NotificationSubscription`, so que dono e' um Contact, e nao um
# User. Existe separada porque aquela e' `belongs_to :user` e nao aceitaria
# um Contact sem reabrir o model inteiro.
class ClientPushSubscription < ApplicationRecord
  belongs_to :account
  belongs_to :contact
end
