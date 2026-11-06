# Senha padrao da Area do Cliente: `password_change_required` marca quem ainda
# esta com a senha padrao e precisa trocar no primeiro acesso, e
# `default_password_set_at` e a data em que ela foi dada (base do prazo
# opcional de validade, CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS).
class AddDefaultPasswordFlagsToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :password_change_required, :boolean, default: false, null: false
    add_column :contacts, :default_password_set_at, :datetime
  end
end
