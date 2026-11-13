# Os modulos dos tutoriais sao editados so' por quem administra a conta (o cliente
# os le por Api::V1::Client::TutorialsController).
class ClientTutorialModulePolicy < ApplicationPolicy
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
