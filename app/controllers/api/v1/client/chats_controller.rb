# O chat do Portal com a equipe - item proprio do menu, sem relacao com
# ticket nenhum.
#
# Uma Conversation de verdade, e nao um molde proprio: nasce na PRIMEIRA vez
# que o cliente abre a tela (ou na primeira mensagem depois da sessao
# anterior ser resolvida - `Client::ChatConversationResolver`), encontra ou
# cria o Inbox "Portal do Cliente" da conta
# (`Inboxes::EnsureClientPortalInboxService`) e o `ContactInbox` do contato
# logado nesse Inbox.
#
# Por isso ela aparece SOZINHA na tela normal de Conversas do atendente - nao
# ha nada de especial do lado de la, e a automacao de triagem roda por cima
# dela como roda em qualquer conversa: `message_created`/`conversation_created`
# disparam normalmente.
class Api::V1::Client::ChatsController < Api::V1::Client::BaseController
  before_action :ensure_chat_allowed

  # So devolve a conversa existente - nao cria uma nova. A conversa nasce
  # apenas quando o cliente envia a primeira mensagem
  # (`Api::V1::Client::ChatMessagesController`). Assim a conversa nunca
  # aparece no painel do atendente antes de haver algo para ler.
  def show
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    @conversation = inbox && Current.account.conversations
                                            .where(inbox_id: inbox.id, contact_id: current_contact.id)
                                            .where.not(status: :resolved)
                                            .order(created_at: :desc)
                                            .first
  end
end
