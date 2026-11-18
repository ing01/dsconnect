# As empresas da conta da chave, para o sistema externo (a IA de triagem) descobrir o
# `company_id` e o Nivel da empresa (`classification_level`, de 1 a 5) sem depender de o
# ticket ja ter uma empresa. So' da conta da chave: id de outra conta e' 404.
#
# Filtros (todos opcionais e combinaveis):
#   - `query`: parte do nome, da razao social, do dominio ou do codigo (sem diferenciar maiuscula);
#   - `cnpj`: o documento inteiro, com ou sem pontuacao (e' unico na conta);
#   - `codigo`: o codigo exato (tambem unico na conta);
#   - `classified`: `true` so' as que ja tem Nivel, `false` so' as sem Nivel.
class Api::V1::Integrations::CompaniesController < Api::V1::Integrations::BaseController
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  def index
    scope = filtered_companies
    @companies_count = scope.count
    @current_page = [params[:page].to_i, 1].max
    @companies = scope.order(:name, :id).page(@current_page).per(per_page)
  end

  def show
    @company = current_account.companies.find(params[:id])
  end

  private

  def filtered_companies
    scope = current_account.companies
    scope = scope.where(cnpj: digits(params[:cnpj])) if params[:cnpj].present?
    scope = scope.where('LOWER(companies.codigo) = ?', params[:codigo].to_s.strip.downcase) if params[:codigo].present?
    scope = apply_query(scope)
    apply_classified(scope)
  end

  def apply_query(scope)
    term = params[:query].to_s.strip
    return scope if term.blank?

    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    scope.where('companies.name ILIKE :like OR companies.legal_name ILIKE :like OR companies.domain ILIKE :like OR companies.codigo ILIKE :like',
                like: like)
  end

  def apply_classified(scope)
    return scope if params[:classified].blank?

    ActiveModel::Type::Boolean.new.cast(params[:classified]) ? scope.where.not(classification_level: nil) : scope.where(classification_level: nil)
  end

  def digits(value)
    value.to_s.gsub(/\D/, '')
  end

  def per_page
    requested = params[:per_page].to_i
    requested.positive? ? [requested, MAX_PER_PAGE].min : DEFAULT_PER_PAGE
  end
end
