class CompanyCredentialPolicy < ApplicationPolicy
  def index?
    can_manage_credentials?
  end

  def show?
    can_manage_credentials?
  end

  def create?
    can_manage_credentials?
  end

  def update?
    can_manage_credentials?
  end

  def destroy?
    can_manage_credentials?
  end

  private

  def can_manage_credentials?
    @account_user.administrator? || @account_user.custom_role&.permissions&.include?('client_credentials_manage')
  end
end
