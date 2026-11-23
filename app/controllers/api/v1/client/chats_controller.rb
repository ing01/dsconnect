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
  #
  # Sem conversa ABERTA, ainda devolve a ULTIMA (resolvida) em vez de nada: e'
  # nela que mora a pesquisa de satisfacao que o encerramento manda sozinha, e
  # um F5 (ou trocar de aba e voltar) nao pode fazer a pessoa perder a chance
  # de responder. A tela decide, pelo `resolved` abaixo, se mostra o composer
  # normal ou o botao de "Iniciar novo chat" no lugar dele.
  def show
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    @conversation = find_conversation(inbox)
  end

  private

  def find_conversation(inbox)
    return nil unless inbox

    conversations = Current.account.conversations
                            .where(inbox_id: inbox.id, contact_id: current_contact.id)
                            .order(created_at: :desc)
    conversations.where.not(status: :resolved).first || conversations.first
  end
end
