# Os filtros da tela interna de SAC: empresa, tipo, assunto, status, solicitante
# e periodo.
#
# Mesma forma do TicketFinder, pelo mesmo motivo: a lista de filtros cresce e
# nao pode crescer dentro do controller. Cada filtro aceita um valor ou uma lista
# (lista vira `IN`, que e o "ou" dentro do mesmo filtro); entre filtros
# diferentes vale "e", porque cada um encadeia outro `where`.
class ManifestationFinder
  DIRECT_ATTRIBUTE_FILTERS = {
    company_id: :company_id,
    contact_id: :contact_id,
    assignee_id: :assignee_id,
    kind: :kind,
    subject_area: :subject_area,
    status: :status,
    display_id: :display_id
  }.freeze

  def initialize(scope:, params:)
    @scope = scope
    @params = params
  end

  def perform
    resultado = filter_by_attributes(@scope)
    resultado = filter_by_period(resultado)
    resultado = filter_by_pending(resultado)
    filter_by_query(resultado)
  end

  private

  attr_reader :params

  def filter_by_attributes(resultado)
    DIRECT_ATTRIBUTE_FILTERS.each do |chave, coluna|
      valor = params[chave]
      next if valor.blank?

      resultado = resultado.where(coluna => normalize(chave, valor))
    end
    resultado
  end

  # Os enums aceitam o nome ("complaint"), que e o que a tela manda. Deixar o
  # Rails converter evita traduzir numero no frontend.
  def normalize(_chave, valor)
    valor.is_a?(Array) ? valor.reject(&:blank?) : valor
  end

  # Periodo pela DATA DE REGISTRO. Os dois lados sao opcionais: filtrar so "a
  # partir de" e um pedido legitimo.
  def filter_by_period(resultado)
    resultado = depois_de(resultado)
    antes_de(resultado)
  end

  def depois_de(resultado)
    return resultado if params[:created_after].blank?

    resultado.where(created_at: parse_date(params[:created_after]).beginning_of_day..)
  end

  def antes_de(resultado)
    return resultado if params[:created_before].blank?

    resultado.where(created_at: ..parse_date(params[:created_before]).end_of_day)
  end

  def parse_date(valor)
    Date.parse(valor.to_s)
  rescue Date::Error
    Date.current
  end

  # "Mostrar so o que esta pendente": o que a equipe usa para achar o que falta
  # responder, sem montar a lista de status na mao.
  def filter_by_pending(resultado)
    return resultado unless ActiveModel::Type::Boolean.new.cast(params[:pending_only])

    resultado.pending
  end

  # A busca livre cobre titulo, descricao e o numero - e o que se tem em maos ao
  # receber um cliente perguntando pela manifestacao dele.
  def filter_by_query(resultado)
    termo = params[:query].to_s.strip
    return resultado if termo.blank?

    numero = termo.delete_prefix('SAC-').delete_prefix('sac-')
    if numero.match?(/\A\d+\z/)
      resultado.where(display_id: numero)
    else
      resultado.where('manifestations.title ILIKE :t OR manifestations.description ILIKE :t', t: "%#{termo}%")
    end
  end
end
