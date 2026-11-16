class MoodEntryPolicy < ApplicationPolicy
  def create?
    true
  end

  def today?
    true
  end

  # O relatorio "Humor da equipe": administrador sempre; os demais (gestores)
  # precisam da permissao `mood_checkin_manage` na funcao personalizada. Registrar
  # o PROPRIO humor (create?/today?) continua liberado para todos.
  def index?
    @account_user.administrator? ||
      @account_user.custom_role&.permissions&.include?('mood_checkin_manage') || false
  end
end
