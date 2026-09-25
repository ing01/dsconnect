# Prioridade Alta/Media/Baixa da triagem automatica, sempre determinada aqui -
# nunca pela IA sozinha. A IA (quando envolvida) so classifica o problema numa
# das 3 faixas; esta classe combina isso com o nivel do cliente e devolve um
# resultado fixo.
#
# `Ticket#priority` continua com 4 valores (low/medium/high/urgent) porque
# `TicketSlaPolicy` depende disso (unicidade por time) - a escala de 3 valores
# pedida mapeia para 3 dos 4: baixa->low, media->medium, alta->high. `urgent`
# fica de fora, reservado para escalonamento manual por uma pessoa (a IA nunca
# atribui `urgent` sozinha).
class Tickets::HelpdeskPriority
  # 1 = Baixa, 2 = Media, 3 = Alta (Company#client_level).
  LEVEL_BASELINE = { 1 => 'baixa', 2 => 'media', 3 => 'alta' }.freeze
  RANK = { 'baixa' => 0, 'media' => 1, 'alta' => 2 }.freeze
  TICKET_PRIORITY = { 'baixa' => 'low', 'media' => 'medium', 'alta' => 'high' }.freeze

  class << self
    # `problema` e opcional - sem ele (por exemplo, a IA falhou e nao
    # classificou nada), usa so o nivel do cliente. A prioridade nunca fica
    # abaixo do que o nivel ja garante, so pode subir com o que a IA apurou.
    def label_for(client_level:, problema: nil)
      baseline = LEVEL_BASELINE.fetch(client_level.to_i, 'baixa')
      candidates = [baseline, problema].select { |label| RANK.key?(label) }
      candidates.max_by { |label| RANK.fetch(label) }
    end

    def ticket_priority_for(client_level:, problema: nil)
      TICKET_PRIORITY.fetch(label_for(client_level: client_level, problema: problema))
    end
  end
end
