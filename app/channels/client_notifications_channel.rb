# O "tem novidade" do app do cliente, em tempo real. O canal nao carrega o
# conteudo da notificacao - so avisa que a lista mudou, e o app a busca em
# `Api::V1::Client::NotificationsController`. Assim o que o cliente pode ver
# continua decidido num lugar so (a lista), nunca no evento.
#
# Autentica pelo mesmo token de API da Area do Cliente: o `RoomChannel` serve
# quem tem `pubsub_token` de uma conversa, e o contato so tem um depois de abrir
# o chat.
class ClientNotificationsChannel < ApplicationCable::Channel
  def self.stream_name(contact)
    "client_notifications_#{contact.id}"
  end

  # Chamado quando algo novo existe para o contato (resposta no chat ou no
  # chamado, chamado encaminhado). Sem contato (ticket sem solicitante), nada a avisar.
  def self.ping(contact)
    return if contact.blank?

    ActionCable.server.broadcast(stream_name(contact), { event: 'client.notification' })
  end

  def subscribed
    contact = AccessToken.find_by(token: params[:api_access_token])&.owner
    return reject unless contact.is_a?(Contact) && contact.client_access?

    stream_from self.class.stream_name(contact)
  end
end
