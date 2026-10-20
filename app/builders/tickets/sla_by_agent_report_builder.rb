# O relatorio de SLA por agente: quanto cada responsavel cumpriu, venceu, e
# quanto tempo de verdade levou - por tipo de relogio (atendimento/estagio/
# solucao) e tambem somado, igual o pedido ("junto ou separado").
#
# Diferente de TicketTimeEntriesReportBuilder, o SLA nao tem um registro por
# PESSOA que apontou - o relogio (TicketAppliedSla) pertence ao TICKET. Por
# isso quem o relatorio credita e' o responsavel ATUAL do ticket (Nivel 1,
# `ticket.assignee`) - se o ticket trocou de responsavel depois que o relogio
# fechou, o relatorio credita quem esta la agora, nao quem estava la quando o
# relogio rodou. E a limitacao que os dados existentes permitem; um historico
# de responsavel por relogio exigiria guardar isso na hora (TicketTimeEntry ja
# faz isso para nivel - SLA ainda nao).
class Tickets::SlaByAgentReportBuilder
  pattr_initialize [:account!, :params!]

  KINDS = TicketAppliedSla.kinds.keys.freeze

  def perform
    {
      totals: totals,
      by_kind: by_kind,
      by_user: by_user,
      by_company: by_company
    }
  end

  private

  def scope
    @scope ||= filter_by_company(filter_by_team(filter_by_kind(filter_by_period(base_scope))))
  end

  def base_scope
    TicketAppliedSla.where(account_id: account.id).joins(:ticket).reorder(nil)
  end

  # Pelo inicio do relogio - mesmo papel que `worked_on` tem no relatorio de
  # horas: e a data que faz sentido para "o que rodou neste periodo".
  def filter_by_period(relation)
    relation = relation.where(started_at: from..) if from
    relation = relation.where(started_at: ..to) if to
    relation
  end

  def filter_by_kind(relation)
    return relation if params[:kind].blank? || params[:kind] == 'all'

    relation.where(kind: params[:kind])
  end

  def filter_by_team(relation)
    return relation if params[:team_id].blank?

    relation.where(tickets: { team_id: params[:team_id] })
  end

  def filter_by_company(relation)
    return relation if params[:company_id].blank?

    relation.where(tickets: { company_id: params[:company_id] })
  end

  def totals
    summarize(scope)
  end

  # Os 3 tipos sempre aparecem, mesmo zerados - um tipo sem relogio e uma
  # informacao (ex: Mesa sem Estagio com prazo), nao uma linha a omitir.
  def by_kind
    KINDS.map { |kind| summarize(scope.where(kind: kind)).merge(kind: kind) }
  end

  # Uma linha por (responsavel, tipo), mais uma linha "all" por responsavel com
  # os 3 tipos somados - e o que deixa o frontend alternar junto/separado sem
  # pedir de novo ao servidor.
  def by_user
    rows = assignee_ids.flat_map do |user_id|
      identity = { user_id: user_id, user_name: user_names[user_id] }
      user_scope = scope.where(tickets: { assignee_id: user_id })
      rows_for_scope(user_scope, identity)
    end
    rows.sort_by { |row| [row[:user_name].to_s, row[:kind] == 'all' ? -1 : KINDS.index(row[:kind])] }
  end

  # O cruzamento que o pedido de margem por Cliente precisa: SLA cumprido (ou
  # nao) e tempo gasto, por Empresa - sem isso so' dava pra ver por agente, e a
  # pergunta era "este Cliente da margem".
  def by_company
    rows = company_ids.flat_map do |company_id|
      identity = { company_id: company_id, company_name: company_names[company_id] }
      company_scope = scope.where(tickets: { company_id: company_id })
      rows_for_scope(company_scope, identity)
    end
    rows.sort_by { |row| [row[:company_name].to_s, row[:kind] == 'all' ? -1 : KINDS.index(row[:kind])] }
  end

  # Uma linha por tipo de relogio dentro do escopo (ja restrito a UM agente ou
  # UMA Empresa pelo chamador), mais uma linha "all" com os 3 somados - e o
  # que deixa o frontend alternar junto/separado sem pedir de novo ao servidor.
  def rows_for_scope(scoped_relation, identity)
    per_kind = KINDS.map { |kind| summarize(scoped_relation.where(kind: kind)).merge(identity).merge(kind: kind) }
    per_kind + [summarize(scoped_relation).merge(identity).merge(kind: 'all')]
  end

  # O numero central de cada linha. `status` decide cumprido/vencido/correndo -
  # NAO `completed_at`: `TicketAppliedSla#mark_missed!` marca vencido sem
  # fechar o relogio (o Estagio/ticket ainda nao saiu de onde estava), entao um
  # relogio pode estar "vencido" com `completed_at` nulo. Tratar isso como
  # "correndo" esconderia exatamente o problema que o relatorio quer mostrar.
  #
  # `actual_hours` (tempo realmente gasto) so' da para medir em quem ja fechou
  # (tem `completed_at`). `overrun_hours` (atraso) soma os dois casos de
  # vencido: quem ja fechou vencido (fim menos prazo) e quem segue vencido e
  # aberto (agora menos prazo) - os dois pesam igual na margem.
  def summarize(relation)
    rows = relation.pluck(:status, :started_at, :completed_at, :due_at, :threshold)

    {
      clocks: rows.size,
      hit: rows.count { |status, *| status == 'hit' },
      missed: rows.count { |status, *| status == 'missed' },
      active: rows.count { |status, *| status == 'active' },
      hit_rate: rate(rows),
      actual_hours: actual_hours(rows),
      overrun_hours: overrun_hours(rows),
      threshold_hours: rows.sum { |_s, _started, _completed, _due, threshold| threshold.to_f } / 3600.0
    }
  end

  def rate(rows)
    hit = rows.count { |status, *| status == 'hit' }
    settled_total = hit + rows.count { |status, *| status == 'missed' }
    return 0.0 if settled_total.zero?

    (hit.to_f / settled_total * 100).round(1)
  end

  # So' da para medir em quem ja fechou (tem `completed_at`).
  def actual_hours(rows)
    fechados = rows.select { |_status, _started, completed, _due, _threshold| completed.present? }
    seconds_sum(fechados) { |_s, started, completed, _due, _t| completed - started } / 3600.0
  end

  # Soma os dois casos de vencido: quem ja fechou vencido (fim menos prazo) e
  # quem segue vencido e aberto - `mark_missed!` marca sem fechar o relogio -
  # (agora menos prazo). Os dois pesam igual na margem.
  def overrun_hours(rows)
    fechados_vencidos = rows.select { |status, _started, completed, _due, _t| status == 'missed' && completed.present? }
    abertos_vencidos = rows.select { |status, _started, completed, _due, _t| status == 'missed' && completed.nil? }

    (
      seconds_sum(fechados_vencidos) { |_s, _started, completed, due, _t| [completed - due, 0].max } +
      seconds_sum(abertos_vencidos) { |_s, _started, _completed, due, _t| [Time.zone.now - due, 0].max }
    ) / 3600.0
  end

  def seconds_sum(rows)
    rows.sum { |row| yield(*row) }
  end

  def assignee_ids
    @assignee_ids ||= Ticket.where(id: scope.select(:ticket_id)).distinct.pluck(:assignee_id).compact
  end

  def company_ids
    @company_ids ||= Ticket.where(id: scope.select(:ticket_id)).distinct.pluck(:company_id).compact
  end

  def user_names
    @user_names ||= User.where(id: assignee_ids).pluck(:id, :name).to_h
  end

  def company_names
    @company_names ||= Company.where(id: company_ids).pluck(:id, :name).to_h
  end

  def from
    @from ||= parse_date(params[:from])
  end

  def to
    @to ||= parse_date(params[:to])
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
