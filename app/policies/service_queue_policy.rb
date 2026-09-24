class ServiceQueuePolicy < ApplicationPolicy
  # Every agent can see queues (needed to filter/transfer conversations); only
  # admins and the owning department's manager can create/edit/delete one.
  def index?
    true
  end

  def show?
    true
  end

  # Pegar a proxima conversa da fila e conveniente pra qualquer atendente,
  # travado ou nao - a trava (`enforce_queue_order`) so restringe a escolha
  # LIVRE, nunca este caminho.
  def claim_next?
    true
  end

  def create?
    administrator? || queue_manager? || team_manager?
  end

  def update?
    administrator? || queue_manager? || team_manager?
  end

  def destroy?
    administrator? || queue_manager? || team_manager?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def queue_manager?
    account_user&.permissions&.include?('queue_manage')
  end

  def team_manager?
    record.team_id.present? && record.team.manager_id == user.id
  end
end
