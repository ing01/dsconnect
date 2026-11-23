# Prioridade Alta/Media/Baixa da triagem automatica, sempre determinada aqui -
# nunca pela IA sozinha. A IA (quando envolvida) so classifica o problema numa
# das 3 faixas; esta classe valida a faixa e devolve um resultado fixo. Sem
# classificacao (a IA falhou ou nao rodou), vale 'baixa'. O cliente nao entra
# mais na conta: a antiga Prioridade da Empresa foi removida.
#
# `Ticket#priority` continua com 4 valores (low/medium/high/urgent) porque
# `TicketSlaPolicy` depende disso (unicidade por time) - a escala de 3 valores
# pedida mapeia para 3 dos 4: baixa->low, media->medium, alta->high. `urgent`
# fica de fora, reservado para escalonamento manual por uma pessoa (a IA nunca
# atribui `urgent` sozinha).
class Tickets::HelpdeskPriority
  DEFAULT_LABEL = 'baixa'.freeze
  RANK = { 'baixa' => 0, 'media' => 1, 'alta' => 2 }.freeze
  TICKET_PRIORITY = { 'baixa' => 'low', 'media' => 'medium', 'alta' => 'high' }.freeze

  class << self
    # `problema` e opcional - sem ele (ou com um valor que nao e uma das 3
    # faixas) cai na prioridade baixa.
    def label_for(problema: nil)
      RANK.key?(problema) ? problema : DEFAULT_LABEL
    end

    def ticket_priority_for(problema: nil)
      TICKET_PRIORITY.fetch(label_for(problema: problema))
    end
  end
end
