# Converte um Crm::Client (+ opcionalmente um Crm::Sale) nos tokens que o
# cadastro ja sabe responder sozinho - usado para pre-preencher o formulario
# de geracao de contrato. Tokens que dependem do negocio especifico (tipo de
# licenca, prazo, se tem treino, etc.) nao tem de onde vir automaticamente e
# ficam em branco, para preenchimento manual a cada contrato.
class Crm::ContractTokenMapper
  # Identidade do cliente - sempre vem do cadastro, NUNCA do que foi digitado
  # na tela de geracao (ver Crm::Contracts::GenerationService, que usa esta
  # lista para fazer esses tokens ganharem de um `data` manual).
  LOCKED_CLIENT_TOKEN_KEYS = %w[
    cliente_razao_social cliente_cnpj cliente_nome_fantasia cliente_email cliente_telefone
  ].freeze

  # Usada por Crm::Contracts::RegenerationService para saber quais tokens
  # trocar quando o representante do cliente muda, sem tocar no resto do
  # `data` ja gravado (licenca, implantacao etc., digitados a mao).
  REPRESENTATIVE_TOKEN_KEYS = %w[
    representante_nome representante_cpf representante_dt_nasc representante_endereco
    representante_end_num representante_bairro representante_end_complemento representante_cidade
    representante_uf representante_cep representante_telefone representante_celular
  ].freeze

  def initialize(client:, sale: nil)
    @client = client
    @sale = sale
  end

  def to_h
    # SEM `.compact`: um valor nil precisa continuar presente no hash, para
    # o DocxFillerService saber que o token existe e so' preencher vazio -
    # nao e' diferente de remover a chave hoje (o filler ja trata ausencia
    # como vazio tambem), mas deixa a intencao explicita.
    client_tokens.merge(sale_tokens)
  end

  private

  attr_reader :client, :sale

  def client_tokens
    {
      'cliente_razao_social' => client.name,
      'cliente_cnpj' => client.cnpj,
      'cliente_nome_fantasia' => client.trade_name,
      'cliente_inscricao_estadual' => client.state_registration,
      'cliente_endereco_rua' => client.address_street,
      'cliente_endereco_num' => client.address_number,
      'cliente_endereco_bairro' => client.address_neighborhood,
      'cliente_endereco_complemento' => client.address_complement,
      'cliente_cidade' => client.city,
      'cliente_uf' => client.state,
      'cliente_cep' => client.zip_code,
      'cliente_telefone' => client.phone,
      'cliente_email' => client.email,
      'representante_nome' => client.representative_name,
      'representante_cpf' => client.representative_cpf,
      'representante_dt_nasc' => client.representative_birth_date&.strftime('%d/%m/%Y'),
      'representante_endereco' => client.representative_address_street,
      'representante_end_num' => client.representative_address_number,
      'representante_bairro' => client.representative_neighborhood,
      'representante_end_complemento' => client.representative_address_complement,
      'representante_cidade' => client.representative_city,
      'representante_uf' => client.representative_state,
      'representante_cep' => client.representative_zip_code,
      'representante_telefone' => client.representative_phone,
      'representante_celular' => client.representative_mobile,
    }
  end

  def sale_tokens
    return {} if sale.blank?

    {
      'valor_licenca' => sale.monthly_value,
      'impl_valor' => sale.implementation_value,
      'for_pag' => sale.payment_method,
      'qtde_licencas' => sale.installments,
    }
  end
end
