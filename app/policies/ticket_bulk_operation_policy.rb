# Qualquer agente usa o painel em lote; a permissao de cada ticket continua
# valendo (TicketPolicy), conferida ticket a ticket na execucao.
class TicketBulkOperationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def preview?
    true
  end

  def undo?
    true
  end

  def retry_failed?
    true
  end
end
