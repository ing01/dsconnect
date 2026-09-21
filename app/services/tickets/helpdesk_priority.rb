# Prioridade Alta/Media/Baixa da triagem automatica, sempre determinada aqui -
# nunca pela IA sozinha. A IA (quando envolvida) so classifica urgencia/impacto;
# esta classe combina isso com o nivel do cliente e devolve um resultado fixo.
#
# `Ticket#priority` continua com 4 valores (low/medium/high/urgent) porque
# `TicketSlaPolicy` depende disso (unicidade por time) - a escala de 3 valores
# pedida mapeia para 3 dos 4: baixa->low, media->medium, alta->urgent. `high`
# fica de fora, reservado para escalonamento manual por uma pessoa.
class Tickets::HelpdeskPriority
  # 1 = Baixa, 2 = Media, 3 = Alta (Company#client_level).
  LEVEL_BASELINE = { 1 => 'baixa', 2 => 'media', 3 => 'alta' }.freeze
  RANK = { 'baixa' => 0, 'media' => 1, 'alta' => 2 }.freeze
  TICKET_PRIORITY = { 'baixa' => 'low', 'media' => 'medium', 'alta' => 'urgent' }.freeze

  class << self
    # `urgencia`/`impacto` sao opcionais - sem eles (por exemplo, um nivel 1/2
    # que a IA resolveu sem precisar classificar nada), usa so o nivel do
    # cliente. A prioridade nunca fica abaixo do que o nivel ja garante, so
    # pode subir com o que a triagem apurou.
    def label_for(client_level:, urgencia: nil, impacto: nil)
      baseline = LEVEL_BASELINE.fetch(client_level.to_i, 'baixa')
      candidates = [baseline, urgencia, impacto].select { |label| RANK.key?(label) }
      candidates.max_by { |label| RANK.fetch(label) }
    end

    def ticket_priority_for(client_level:, urgencia: nil, impacto: nil)
      TICKET_PRIORITY.fetch(label_for(client_level: client_level, urgencia: urgencia, impacto: impacto))
    end
  end
end
