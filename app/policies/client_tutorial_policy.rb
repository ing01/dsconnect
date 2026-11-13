# Os tutoriais da Area do Cliente sao editados so' por quem administra a conta; o
# cliente os le por outro caminho (Api::V1::Client::TutorialsController).
class ClientTutorialPolicy < ApplicationPolicy
  def index?
    administrator?
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def destroy?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
