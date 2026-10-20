# Marca que o CONTATO ja' abriu ou removeu um item da aba Notificacoes do
# Portal do Cliente. Os itens sao sinteticos (communication_#id, chat_#id) -
# nao ha uma tabela de notificacao de verdade do lado do cliente (ver
# Api::V1::Client::NotificationsController) - entao so' a CHAVE do item fica
# guardada aqui, nao o item em si.
class ClientNotificationDismissal < ApplicationRecord
  belongs_to :account
  belongs_to :contact

  validates :item_key, presence: true, uniqueness: { scope: :contact_id }
end
