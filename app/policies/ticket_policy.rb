class TicketPolicy < ApplicationPolicy
  # Kanban visibility is account-wide today, regardless of Mesa (Team), so
  # every agent/admin can see and create tickets. Mutating a ticket
  # (assignee/team/priority/status/deletion) is restricted to admins, the
  # current assignee, or a member of the ticket's Mesa (team).
  def index?
    true
  end

  # Exportar e ler o mesmo que a Busca detalhada ja mostra, com os mesmos
  # filtros - quem pode ver a lista pode leva-la em arquivo.
  def export?
    index?
  end

  # Ler o tamanho da fila da Triagem e ler a lista: a tela esta aberta a qualquer
  # agente, e o contador nao conta nada que ela ja nao mostre.
  def triage_count?
    index?
  end

  def show?
    true
  end

  # Resumir a conversa pra descricao e' leitura (gera um texto, nao MUDA nada
  # no ticket) - mesma regra de quem pode ver.
  def summarize_conversation?
    show?
  end

  def create?
    true
  end

  def update?
    editable? && permitted_to_handle?
  end

  # Um ticket fechado ou cancelado nao aceita mais alteracao - so reabrir. A
  # regra de verdade esta no model (TicketFinalizable); aqui ela se repete para
  # a API recusar antes de tentar e para a tela ja nascer com os controles
  # desabilitados, em vez de deixar o agente descobrir no erro.
  def editable?
    # `record` e a classe nas acoes de colecao (index/export), onde nao ha
    # ticket para avaliar.
    return true unless record.is_a?(Ticket)

    !record.finalized?
  end

  def permitted_to_handle?
    administrator? || assigned_to_user? || team_member?
  end

  def move?
    update?
  end

  def assign?
    update?
  end

  def resolve?
    update?
  end

  # A excecao: sem isto um ticket finalizado nao teria como voltar, porque
  # reabrir tambem passa pelo `update?`.
  def reopen?
    permitted_to_handle?
  end

  def close?
    update?
  end

  def cancel?
    update?
  end

  # Classifying and writing to the customer are part of handling the ticket.
  def classify?
    update?
  end

  # Impedir e liberar sao tratativas do ticket, nao encerramento: seguem a mesma
  # regra de `update?` - ticket nao finalizado, e quem atende (admin, responsavel
  # ou membro da Mesa).
  def block?
    update?
  end

  def unblock?
    update?
  end

  # Every composite action from the "Acoes do ticket" menu is a mutation of the
  # ticket, so they all sit behind the same rule as `update?` - the frontend
  # hiding a menu entry is a convenience, never the check.
  def transfer?
    update?
  end

  def create_child?
    # Opening a child is creating a ticket, which every agent may do; the parent
    # itself is not modified beyond gaining an activity entry.
    create?
  end

  def duplicate?
    create?
  end

  def set_parent?
    update?
  end

  def merge?
    update?
  end

  def assign_to_me?
    update?
  end

  # Extending a deadline is a commercial decision, not routine ticket handling:
  # restricted to admins and to the agent who owns the ticket.
  #
  # `editable?` tambem entra aqui: o prazo vive noutra tabela, entao a validacao
  # do model nao o alcanca, e sem esta linha daria para esticar o SLA de um
  # ticket ja fechado.
  def add_sla_hours?
    editable? && (administrator? || assigned_to_user?)
  end

  # Aceitar um chamado do cliente e encaminha-lo. Nao segue `update?` de
  # proposito: o chamado em triagem ainda nao tem responsavel, e a Mesa de
  # entrada foi escolhida pela Categoria - exigir ser membro dela deixaria a
  # fila parada sempre que a Categoria apontasse para a Mesa errada, que e
  # justamente o que a triagem existe para corrigir.
  def approve_triage?
    editable?
  end

  def destroy?
    administrator?
  end

  # Provisioning the default Mesa takes no user input (the name is fixed) and only
  # fires when the account has none at all, so it isn't gated on `administrator?`
  # the way TeamPolicy#create? is - otherwise an agent opening the Kanban first on
  # a fresh account would hit a dead end.
  def ensure_default_mesa?
    true
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def assigned_to_user?
    record.assignee_id.present? && record.assignee_id == user.id
  end

  def team_member?
    record.team_id.present? && record.team.members.exists?(id: user.id)
  end
end
