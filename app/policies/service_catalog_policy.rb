class ServiceCatalogPolicy < ApplicationPolicy
  # Every agent reads the catalogue to classify a ticket; only admins shape it,
  # the same rule the Estagios and Categorias follow.
  def index?
    true
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
