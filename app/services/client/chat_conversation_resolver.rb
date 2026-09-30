# A conversa "de agora" do chat do Portal, para este Contato.
#
# Uma conversa RESOLVIDA e' uma sessao encerrada - a proxima mensagem do
# cliente comeca uma sessao NOVA (mesmo Inbox, mesmo Contato, Conversation
# diferente), em vez de reabrir a antiga. E' o mesmo padrao que WhatsApp/SMS/
# Telegram ja usam aqui (`conversations.where.not(status: :resolved).last ||
# create`) - e' isso que faz o Portal ter "historico de conversas" em vez de
# uma so, infinita.
class Client::ChatConversationResolver
  pattr_initialize [:account!, :contact!]

  def perform
    inbox = ::Inboxes::EnsureClientPortalInboxService.new(account: account).perform
    open_conversation(inbox) || create_conversation!(inbox)
  end

  private

  def open_conversation(inbox)
    account.conversations
           .where(inbox_id: inbox.id, contact_id: contact.id)
           .where.not(status: :resolved)
           .order(created_at: :desc)
           .first
  end

  def create_conversation!(inbox)
    contact_inbox = ::ContactInboxBuilder.new(contact: contact, inbox: inbox).perform

    account.conversations.create!(
      inbox_id: inbox.id,
      contact_id: contact.id,
      contact_inbox_id: contact_inbox.id
    )
  end
end
