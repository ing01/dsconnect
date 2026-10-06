# Celular do representante, separado do telefone - o contrato pede os dois
# (`representante_telefone` e `representante_celular`).
class AddRepresentativeMobileToCrmClients < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_clients, :representative_mobile, :string
  end
end
