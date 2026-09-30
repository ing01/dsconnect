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
  def show
    @conversation = ::Client::ChatConversationResolver.new(account: Current.account, contact: current_contact).perform
  end
end
