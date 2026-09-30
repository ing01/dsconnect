# O chat do Portal com a equipe - item proprio do menu, sem relacao com
# ticket nenhum.
#
# Uma Conversation de verdade, e nao um molde proprio: nasce na PRIMEIRA vez
# que o cliente abre a tela, encontra ou cria o Inbox "Portal do Cliente" da
# conta (`Inboxes::EnsureClientPortalInboxService`) e o `ContactInbox` do
# contato logado nesse Inbox.
#
# Por isso ela aparece SOZINHA na tela normal de Conversas do atendente - nao
# ha nada de especial do lado de la, e a automacao de triagem roda por cima
# dela como roda em qualquer conversa: `message_created`/`conversation_created`
# disparam normalmente.
class Api::V1::Client::ChatsController < Api::V1::Client::BaseController
  def show
    @conversation = find_or_create_conversation
  end

  private

  def find_or_create_conversation
    inbox = client_portal_inbox
    existing_conversation(inbox) || create_conversation!(inbox)
  end

  def existing_conversation(inbox)
    Current.account.conversations.find_by(inbox_id: inbox.id, contact_id: current_contact.id)
  end

  def client_portal_inbox
    ::Inboxes::EnsureClientPortalInboxService.new(account: Current.account).perform
  end

  def create_conversation!(inbox)
    contact_inbox = ::ContactInboxBuilder.new(contact: current_contact, inbox: inbox).perform

    Current.account.conversations.create!(
      inbox_id: inbox.id,
      contact_id: current_contact.id,
      contact_inbox_id: contact_inbox.id
    )
  end
end
