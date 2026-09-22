# O relatorio de apontamentos: quanto tempo foi gasto, por nivel e por pessoa.
#
# Responde as perguntas do pedido - quanto o Nivel 1 gastou no atendimento,
# quanto o Nivel 2 gastou na analise, quem apontou e quanto - sobre os mesmos
# TicketTimeEntry que a aba do ticket ja grava. Nao ha tabela de relatorio.
#
# Todos os filtros sao opcionais e se acumulam.
class Tickets::TimeEntriesReportBuilder
  pattr_initialize [:account!, :params!]

  def perform
    {
      totals: totals,
      by_level: by_level,
      by_user: by_user
    }
  end

  private

  def scope
    @scope ||= filter_by_team(filter_by_attributes(filter_by_period(account.ticket_time_entries.reorder(nil))))
  end

  def filter_by_period(relation)
    relation = relation.where(worked_on: from..) if from
    relation = relation.where(worked_on: ..to) if to
    relation
  end

  # Cada filtro e opcional e se acumula: nivel, pessoa e categoria juntos
  # respondem "quanto o Nivel 2 gastou em desenvolvimento".
  def filter_by_attributes(relation)
    { level: params[:level], user_id: params[:user_id], category: params[:category] }
      .compact_blank
      .reduce(relation) { |result, (column, value)| result.where(column => value) }
  end

  # A Mesa nao esta no apontamento: vem do ticket. Um join, e nao uma coluna
  # copiada, para a Mesa continuar sendo do ticket.
  def filter_by_team(relation)
    return relation if params[:team_id].blank?

    relation.joins(:ticket).where(tickets: { team_id: params[:team_id] })
  end

  def totals
    { hours: scope.sum(:hours).to_f, entries: scope.count }
  end

  # Os niveis sempre aparecem, mesmo zerados: um Nivel 2 sem apontamento e uma
  # informacao - significa que nada foi escalado -, e nao uma linha a omitir.
  #
  # A chave `null` reune quem apontou sem ser responsavel do ticket.
  def by_level
    totals_by_level = scope.group(:level).sum(:hours)

    (levels + [nil]).map do |level|
      { level: level, hours: totals_by_level[level].to_f }
    end
  end

  # Os niveis do relatorio sao os que a CONTA usa - o maior numero entre as Mesas
  # dela -, e nao os cinco que o sistema sabe guardar: um Nivel 4 zerado numa
  # conta que atende em dois seria uma linha sobre nada.
  #
  # Filtrado por uma Mesa, sao os niveis daquela Mesa.
  def levels
    @levels ||= begin
      mesas = account.teams.where(assignee_levels_enabled: true)
      mesas = mesas.where(id: params[:team_id]) if params[:team_id].present?
      maximo = mesas.maximum(:assignee_levels_count) || AssigneeLeveled::MIN_LEVEL
      (AssigneeLeveled::FIRST_LEVEL..maximo).to_a
    end
  end

  # Quem apontou, quanto, e em que nivel. Uma pessoa que atuou nos dois niveis
  # aparece uma vez em cada, que e o que permite ler "Nivel 1: Joao 12h30".
  def by_user
    rows = scope.group(:user_id, :level).sum(:hours).map do |(user_id, level), hours|
      { user_id: user_id, user_name: user_names[user_id], level: level, hours: hours.to_f }
    end
    # Por nivel, e dentro dele do maior para o menor: e como o relatorio e lido.
    # Quem nao tem nivel vai para o fim.
    rows.sort_by { |row| [row[:level] || 99, -row[:hours]] }
  end

  def user_names
    @user_names ||= User.where(id: scope.distinct.pluck(:user_id)).pluck(:id, :name).to_h
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
