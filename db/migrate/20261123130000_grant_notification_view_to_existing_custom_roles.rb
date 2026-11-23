# A aba Notificacoes passou a depender da permissao `notification_view` nas funcoes personalizadas.
# Para ninguem perder a aba que ja via, toda funcao existente recebe a permissao. So' ACRESCENTA:
# o que cada funcao ja tinha fica como esta, e quem quiser tirar a aba de uma funcao desmarca a
# permissao na tela de Funcoes personalizadas.
class GrantNotificationViewToExistingCustomRoles < ActiveRecord::Migration[7.2]
  class MigrationCustomRole < ApplicationRecord
    self.table_name = 'custom_roles'
  end

  def up
    MigrationCustomRole.find_each do |role|
      permissions = Array(role.permissions)
      next if permissions.include?('notification_view')

      role.update_columns(permissions: permissions + ['notification_view'])
    end
  end

  def down
    MigrationCustomRole.find_each do |role|
      role.update_columns(permissions: Array(role.permissions) - ['notification_view'])
    end
  end
end
