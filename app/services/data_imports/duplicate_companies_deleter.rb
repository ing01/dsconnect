# Apaga as Empresas que `CompanyCnpjCheckJob#record_duplicate_companies`
# marcou como duplicata (mesmo nome, sem CNPJ, com uma outra Empresa "mais
# certa" do mesmo grupo preservada - ver a regra completa la no job) e
# gravou em `stats['duplicate_company_ids']`.
#
# Mesma ressalva do `UnmatchedCompaniesDeleter`: `dependent: :nullify` no
# model preserva Contato/Ticket/Manifestacao/Pesquisa (so ficam sem empresa
# vinculada), mas Credenciais e Modulos de Sistema da Empresa
# (`dependent: :destroy`) sao apagados junto.
class DataImports::DuplicateCompaniesDeleter
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
    @companies ||= @account.companies.where(id: duplicate_company_ids)
  end

  def duplicate_company_ids
    Array(@data_import.stats['duplicate_company_ids'])
  end
end
