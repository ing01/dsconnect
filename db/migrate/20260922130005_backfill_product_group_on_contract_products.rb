# Cada linha de contrato apontava pra um Produto - agora aponta pro Grupo de
# Produtos daquele produto (todo produto tem um grupo desde a migration
# anterior, entao isso sempre acha um valor).
class BackfillProductGroupOnContractProducts < ActiveRecord::Migration[7.2]
  class MigrationContractProduct < ActiveRecord::Base
    self.table_name = 'contract_products'
  end

  class MigrationProduct < ActiveRecord::Base
    self.table_name = 'products'
  end

  def up
    MigrationContractProduct.where(product_group_id: nil).find_each do |line|
      product = MigrationProduct.find_by(id: line.product_id)
      line.update!(product_group_id: product.product_group_id) if product
    end
  end

  def down
    # Nao reverte - a coluna `product_id` original ja foi removida na
    # migration seguinte quando isso rodar em ordem.
  end
end
