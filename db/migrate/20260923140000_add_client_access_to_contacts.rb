# Acesso do contato a Area do Cliente.
#
# A identidade do cliente e o CONTATO que ja existe - nao ha cadastro novo de
# cliente, nem usuario interno espelhado. O que falta ao contato para entrar e
# apenas credencial: as colunas abaixo sao as mesmas que o Devise usa no User,
# entao o hash da senha e a recuperacao seguem exatamente o padrao do sistema.
#
# Por que nao um User com papel "cliente": `agents_controller#index` lista
# `Current.account.users` sem filtrar papel, e o cliente apareceria na lista de
# agentes, nos seletores de responsavel e na contagem de assentos.
class AddClientAccessToContacts < ActiveRecord::Migration[7.2]
  def change
    # Devise :database_authenticatable e :recoverable, os mesmos campos da
    # tabela `users`.
    add_column :contacts, :encrypted_password, :string, default: '', null: false
    add_column :contacts, :reset_password_token, :string
    add_column :contacts, :reset_password_sent_at, :datetime

    # A chave que a equipe interna liga e desliga. Desligada, o contato existe
    # como sempre existiu e nao entra na Area do Cliente.
    add_column :contacts, :client_access_enabled, :boolean, default: false, null: false
    add_column :contacts, :client_access_enabled_at, :datetime
    add_column :contacts, :client_last_sign_in_at, :datetime

    # Ate onde ele enxerga dentro da propria empresa: so os tickets em que e o
    # solicitante (padrao) ou todos os da empresa. E a "regra definida para os
    # contatos" - sem ela, ou todo contato ve tudo da empresa, ou ninguem ve
    # nada alem do proprio.
    add_column :contacts, :client_tickets_visibility, :integer, default: 0, null: false

    add_index :contacts, :reset_password_token, unique: true
    # Parcial: a esmagadora maioria dos contatos nao tem acesso, e a consulta
    # que importa e "quem tem".
    add_index :contacts, [:account_id, :client_access_enabled],
              where: 'client_access_enabled', name: 'index_contacts_on_account_and_client_access'
  end
end
