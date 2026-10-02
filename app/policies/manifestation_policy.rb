# O SAC do lado interno.
#
# Toda a equipe LE e responde: uma reclamacao parada por falta de permissao e
# pior do que uma vista por quem nao precisava. O que fica com o administrador e
# o que nao se desfaz - converter em ticket e excluir.
class ManifestationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  # A manifestacao nasce no Portal, pelo cliente. A equipe pode registrar uma
  # recebida por telefone ou presencialmente - e o mesmo canal, so que anotado
  # por quem ouviu.
  def create?
    true
  end

  # Mudar status, assumir o caso, responder e anotar: o trabalho do dia.
  def update?
    true
  end

  # Converter cria um ticket de verdade no Kanban da equipe. Fica com quem
  # administra para que um clique exploratorio nao produza chamado.
  def convert?
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
