# Looks up a Brazilian company's registration data by CNPJ using BrasilAPI
# (https://brasilapi.com.br), a free public mirror of Receita Federal data.
# Used only to prefill the company registration form; the agent can still
# edit every field afterwards.
class Companies::CnpjLookupService
  BASE_URL = 'https://brasilapi.com.br/api/cnpj/v1'.freeze
  REQUEST_TIMEOUT = 5 # seconds

  def initialize(raw_cnpj)
    @raw_cnpj = raw_cnpj
  end

  def perform
    return { error: I18n.t('errors.companies.cnpj.invalid') } unless valid_format?

    response = fetch_from_provider
    return { error: I18n.t('errors.companies.cnpj.lookup_failed') } unless response&.success?

    { data: normalize(response.parsed_response) }
  rescue Net::ReadTimeout, Net::OpenTimeout, HTTParty::Error, SocketError => e
    Rails.logger.warn("[CNPJ_LOOKUP] failed for #{cnpj}: #{e.message}")
    { error: I18n.t('errors.companies.cnpj.lookup_failed') }
  end

  private

  def cnpj
    @cnpj ||= @raw_cnpj.to_s.gsub(/\D/, '')
  end

  def valid_format?
    cnpj.match?(/\A\d{14}\z/)
  end

  def fetch_from_provider
    HTTParty.get("#{BASE_URL}/#{cnpj}", timeout: REQUEST_TIMEOUT)
  end

  def normalize(data)
    {
      cnpj: cnpj,
      name: data['nome_fantasia'].presence || data['razao_social'],
      legal_name: data['razao_social'],
      address_zip_code: data['cep'],
      address_street: data['logradouro'],
      address_number: data['numero'],
      address_complement: data['complemento'],
      address_neighborhood: data['bairro'],
      address_city: data['municipio'],
      address_state: data['uf'],
      is_active: data['descricao_situacao_cadastral'].to_s.upcase == 'ATIVA'
    }
  end
end
