# Codigo de referencia do cliente no sistema de origem (planilha de
# Codigo/CNPJ/Prioridade) - igual em espirito ao Contact#identifier, so que
# para Empresa. Mais confiavel que casar so por CNPJ entre reimportacoes da
# mesma planilha, porque o CNPJ pode ainda nao estar cadastrado certinho.
class AddCodigoToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :codigo, :string
    add_index :companies, %i[account_id codigo], unique: true, where: 'codigo IS NOT NULL',
                                                   name: 'index_companies_on_account_and_codigo'
  end
end
