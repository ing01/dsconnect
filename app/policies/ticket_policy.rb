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

  def show?
    true
  end

  def create?
    true
  end

  def update?
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

  def reopen?
    update?
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
  def add_sla_hours?
    administrator? || assigned_to_user?
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
