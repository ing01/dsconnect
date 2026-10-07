# Apaga as Empresas da conta que NAO aparecem na planilha de uma comparacao
# de CNPJ ja concluida (`CompanyCnpjCheckJob` grava os ids em
# `stats['unmatched_company_ids']`) - pedido da Ingrid pra ter controle do
# que esta cadastrado vs. a planilha de origem.
#
# So' mexe em Empresa. `dependent: :nullify` no model (ver
# app/models/company.rb, enterprise) ja garante que Contato, Ticket,
# Manifestacao e Pesquisa de Satisfacao NAO somem junto - so ficam sem
# empresa vinculada. Credenciais e Modulos de Sistema cadastrados na Empresa
# (`dependent: :destroy`) SAO apagados junto - o controller precisa deixar
# isso claro antes de pedir a confirmacao.
class DataImports::UnmatchedCompaniesDeleter
  def initialize(data_import:)
    @data_import = data_import
    @account = data_import.account
  end

  def perform
    ids = companies.pluck(:id)
    companies.find_each(&:destroy)
    ids.size
  end

  private

  def companies
    @companies ||= @account.companies.where(id: unmatched_company_ids)
  end

  def unmatched_company_ids
    Array(@data_import.stats['unmatched_company_ids'])
  end
end
