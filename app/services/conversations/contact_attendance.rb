# O cliente que ja esta sendo atendido por OUTRA pessoa.
#
# Uma regra so', usada pelos DOIS lados que precisam dela:
#   - o bloqueio de `ConversationsController#create`, que recusa abrir outra conversa com
#     ele (sem isso, dois atendentes falavam com o mesmo cliente ao mesmo tempo);
#   - o aviso ANTECIPADO da tela (`ContactsController#attendance`), que mostra quem esta
#     atendendo antes de a pessoa preencher o formulario - e nao so' depois de enviar.
# Com duas copias da regra, o aviso diria uma coisa e o bloqueio outra.
#
# Vale para o contato em QUALQUER caixa da conta (o cliente e' o mesmo), so' para conversa
# ABERTA com responsavel, e so' quando o responsavel nao e' quem esta tentando: quem ja
# atende pode seguir.
class Conversations::ContactAttendance
  pattr_initialize [:account!, :contact_id!, :user!]

  # A conversa aberta que prende o cliente com outra pessoa (a de atividade mais recente),
  # ou nil.
  def by_someone_else
    account.conversations.open
           .where(contact_id: contact_id)
           .where.not(assignee_id: [nil, user.id])
           .includes(:assignee)
           .order(last_activity_at: :desc)
           .first
  end
end
