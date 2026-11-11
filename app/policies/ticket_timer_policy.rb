# Quem apontava horas no ticket pode usar o cronometro. O que limita e' o escopo do
# controller: cada pessoa so enxerga e mexe nos proprios cronometros.
class TicketTimerPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def pause?
    true
  end

  def resume?
    true
  end

  def finish?
    true
  end

  def destroy?
    true
  end
end
