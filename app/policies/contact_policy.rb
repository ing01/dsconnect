class ContactPolicy < ApplicationPolicy
  def index?
    true
  end

  def active?
    true
  end

  def import?
    @account_user.administrator?
  end

  def export?
    @account_user.administrator?
  end

  def search?
    true
  end

  def filter?
    true
  end

  def update?
    true
  end

  def contactable_inboxes?
    true
  end

  def destroy_custom_attributes?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def avatar?
    true
  end

  def destroy?
    @account_user.administrator?
  end

  # Liberar acesso a Area do Cliente e emitir uma credencial de login para
  # alguem de fora - decisao de administrador, e nao tratativa de atendimento.
  # Por isso fica ao lado de `destroy?`/`import?`, e nao de `update?`.
  def client_access?
    @account_user.administrator?
  end
end

ContactPolicy.prepend_mod_with('ContactPolicy')
