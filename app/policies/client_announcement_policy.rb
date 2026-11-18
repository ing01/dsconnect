# O Mural de Avisos do Portal e' editado so' por quem administra a conta; o
# cliente o le por outro caminho (Api::V1::Client::AnnouncementsController).
class ClientAnnouncementPolicy < ApplicationPolicy
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
