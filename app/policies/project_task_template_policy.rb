class ProjectTaskTemplatePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    can_customize?
  end

  def update?
    can_customize?
  end

  def destroy?
    can_customize?
  end

  private

  # Modulos e Tarefas sao o que o perfil de acesso de implantacao personaliza: o administrador e
  # quem tem `project_manage` (o mesmo da tela de Projetos).
  def can_customize?
    account_user&.administrator? || account_user&.permissions&.include?('project_manage')
  end
end
