# Cliente do DueRules, a base de regras de negocio do ERP da Duesoft.
#
# O DueRules e' um servidor MCP: as ferramentas dele (`buscar_regras`,
# `perfil_da_empresa`, `listar_clientes`...) sao chamadas por JSON-RPC sobre
# HTTP em `POST /mcp`, e a resposta vem como um evento SSE com o JSON dentro de
# `data:`. O servidor nao guarda sessao, entao cada chamada e' independente (nao
# ha `initialize` antes).
#
# Configuracao, por variavel de ambiente (ou InstallationConfig):
#   DUERULES_URL         - ex.: https://192.168.0.3:8090/mcp
#   DUERULES_TOKEN       - token `dsrag_...` deste servidor. NUNCA no repositorio.
#   DUERULES_VERIFY_SSL  - 'false' quando o servidor usa certificado emitido por
#                          ele mesmo (e' o caso hoje, na rede interna da Duesoft).
#   DUERULES_TIMEOUT     - segundos (padrao 20).
#
# Sem URL e token, `configured?` e' falso e as ferramentas do Copiloto nem
# aparecem: a funcionalidade liga sozinha quando alguem configura.
class Duerules::Client
  class Error < StandardError; end

  DEFAULT_TIMEOUT = 20

  def self.configured?
    new.configured?
  end

  def configured?
    url.present? && token.present?
  end

  # Chama uma ferramenta e devolve o TEXTO que ela respondeu (o DueRules ja
  # responde em JSON dentro do texto). Levanta `Duerules::Error` em qualquer
  # falha, para quem chama decidir o que dizer ao atendente.
  def call_tool(name, arguments = {})
    raise Error, 'DueRules nao esta configurado' unless configured?

    body = { jsonrpc: '2.0', id: SecureRandom.random_number(1_000_000), method: 'tools/call',
             params: { name: name, arguments: arguments.compact } }
    parse(post(body))
  end

  private

  def url
    @url ||= GlobalConfigService.load('DUERULES_URL', nil).presence
  end

  def token
    @token ||= GlobalConfigService.load('DUERULES_TOKEN', nil).presence
  end

  def verify_ssl?
    GlobalConfigService.load('DUERULES_VERIFY_SSL', 'true').to_s.downcase != 'false'
  end

  def timeout
    GlobalConfigService.load('DUERULES_TIMEOUT', DEFAULT_TIMEOUT).to_i.clamp(2, 120)
  end

  def post(body)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl? && !verify_ssl?
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json, text/event-stream'
    request.body = body.to_json

    http.request(request)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "Nao foi possivel falar com o DueRules (#{e.class})"
  end

  def parse(response)
    raise Error, 'Token do DueRules recusado' if response.code.to_i == 401
    raise Error, "DueRules respondeu HTTP #{response.code}" unless response.code.to_i == 200

    payload = extract_json(response.body.to_s)
    raise Error, "DueRules: #{payload.dig('error', 'message')}" if payload['error']

    result = payload['result'] || {}
    text = Array(result['content']).filter_map { |part| part['text'] if part['type'] == 'text' }.join("\n")
    raise Error, text.presence || 'DueRules devolveu um erro' if result['isError']

    text
  end

  # A resposta e' SSE (`event: message` + `data: {json}`); aceita tambem JSON puro.
  def extract_json(body)
    data_lines = body.lines.filter_map { |line| line.sub(/\Adata:\s?/, '').strip if line.start_with?('data:') }
    JSON.parse(data_lines.presence ? data_lines.join : body)
  rescue JSON::ParserError
    raise Error, 'Resposta do DueRules ilegivel'
  end
end
