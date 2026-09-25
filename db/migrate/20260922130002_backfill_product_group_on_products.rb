# Produtos criados antes do cadastro de Grupo de Produtos existir nao tem
# grupo nenhum - cria um grupo "Geral" por conta (so pra quem tiver produto
# orfao) e encaixa todos ali, pra `product_group_id` poder virar obrigatorio
# na proxima migration sem quebrar nada que ja existia.
class BackfillProductGroupOnProducts < ActiveRecord::Migration[7.2]
  class MigrationProduct < ActiveRecord::Base
    self.table_name = 'products'
  end

  class MigrationProductGroup < ActiveRecord::Base
    self.table_name = 'product_groups'
  end

  def up
    MigrationProduct.where(product_group_id: nil).group(:account_id).count.each_key do |account_id|
      group = MigrationProductGroup.create!(account_id: account_id, name: 'Geral', total_value_mode: 'auto')
      MigrationProduct.where(account_id: account_id, product_group_id: nil).update_all(product_group_id: group.id)
    end
  end

  def down
    # Nao reverte - apagar o vinculo deixaria `product_group_id` sem valor
    # justamente pra migration seguinte, que exige ele preenchido.
  end
end
