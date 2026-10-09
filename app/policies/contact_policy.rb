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
  # alguem de fora - qualquer agente pode fazer isso, e nao so' administrador
  # (pedido explicito: quem atende o cliente e quem sabe que ele precisa de
  # acesso ao Portal).
  def client_access?
    true
  end
end

ContactPolicy.prepend_mod_with('ContactPolicy')
