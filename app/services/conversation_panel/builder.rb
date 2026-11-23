# Monta o payload do Painel de Conversas: cada conversa ABERTA cai em exatamente
# uma faixa:
#
#   verde    - ja atribuida a um atendente (em atendimento)
#   laranja  - na fila: sem atendente, espera ate o limite (orange_until_minutes)
#   vermelho - na fila: sem atendente, espera acima do limite
#
# O tempo conta desde a ultima mensagem do cliente sem resposta (waiting_since).
# Pausadas e adiadas ficam fora das faixas (so contadores). Uma consulta agregada
# para os numeros e uma consulta limitada por faixa para as listas.
class ConversationPanel::Builder
  PREVIEW_LENGTH = 140
  BANDS = %i[green orange red].freeze

  def initialize(account, setting: ConversationPanelSetting.for(account), now: Time.current)
    @account = account
    @setting = setting
    @now = now
  end

  def perform
    {
      settings: settings_json,
      generated_at: @now,
      counts: counts,
      by_agent: breakdown(:assignee_id),
      handled_today: handled_today,
      conversations: BANDS.index_with { |band| conversations_in(band) }
    }
  end

  private

  def open_scope
    @account.conversations.open
  end

  def threshold(minutes)
    @now - minutes.minutes
  end

  def band_conditions
    @band_conditions ||= begin
      limit = threshold(@setting.orange_until_minutes)
      {
        green: 'conversations.assignee_id IS NOT NULL',
        orange: sanitize('conversations.assignee_id IS NULL AND (conversations.waiting_since IS NULL OR conversations.waiting_since > ?)', limit),
        red: sanitize('conversations.assignee_id IS NULL AND conversations.waiting_since <= ?', limit)
      }
    end
  end

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([sql, *binds])
  end

  def band_counts_sql
    BANDS.map { |band| "COUNT(*) FILTER (WHERE #{band_conditions[band]})" }
  end

  def counts
    green, orange, red, total, unassigned = open_scope.pick(
      *(band_counts_sql + [
        'COUNT(*)',
        'COUNT(*) FILTER (WHERE conversations.assignee_id IS NULL)'
      ]).map { |sql| Arel.sql(sql) }
    )

    longest = longest_wait

    {
      green: green.to_i, orange: orange.to_i, red: red.to_i, total: total.to_i,
      unassigned: unassigned.to_i,
      paused: @account.conversations.snoozed.count,
      longest_wait_seconds: longest&.dig(:seconds), longest_wait_conversation: longest,
      average_first_response_seconds: average_first_response
    }
  end

  # O cliente que mais espera NA FILA (aberta, sem atendente): quem e' e ha quanto tempo.
  def longest_wait
    conversation = open_scope.where(assignee_id: nil).where.not(waiting_since: nil)
                             .includes(:contact).order(:waiting_since, :id).first
    return if conversation.nil?

    {
      id: conversation.id,
      display_id: conversation.display_id,
      contact_name: conversation.contact&.name,
      waiting_since: conversation.waiting_since,
      seconds: [(@now - conversation.waiting_since).to_i, 0].max
    }
  end

  # Espera media da fila ate o PRIMEIRO atendimento: das conversas que chegaram
  # hoje e ja tiveram a primeira resposta de um atendente, o tempo entre a chegada
  # e essa resposta.
  def average_first_response
    average = @account.conversations
                      .where(created_at: day_start..@now)
                      .where.not(first_reply_created_at: nil)
                      .where('conversations.first_reply_created_at >= conversations.created_at')
                      .average(Arel.sql('EXTRACT(EPOCH FROM (conversations.first_reply_created_at - conversations.created_at))'))
    average&.to_i
  end

  # Quantas conversas de cada faixa por agente.
  def breakdown(column)
    rows = open_scope.group(column).pluck(Arel.sql(column.to_s), *band_counts_sql.map { |sql| Arel.sql(sql) })
    names = names_for(rows.map(&:first).compact)

    rows.map do |key, green, orange, red|
      { id: key, name: names[key], green: green, orange: orange, red: red, total: green + orange + red }
    end.sort_by { |row| [-row[:red], -row[:orange], -row[:total]] }
  end

  def names_for(ids)
    return {} if ids.empty?

    User.where(id: ids).pluck(:id, :name).to_h
  end

  # Inicio do dia no fuso da conta (padrao: Sao Paulo), nao em UTC.
  def day_start
    zone = @account.reporting_timezone.presence || 'America/Sao_Paulo'
    @now.in_time_zone(zone).beginning_of_day
  end

  # Quantas conversas cada agente atendeu HOJE: as que ele resolveu hoje (pelo
  # evento de resolucao) + as que estao com ele em atendimento agora (abertas).
  # Uma conversa reaberta conta so' como em atendimento, nunca duas vezes.
  def handled_today
    resolved_ids = ReportingEvent.where(account_id: @account.id, name: 'conversation_resolved', created_at: day_start..@now)
                                 .select(:conversation_id)
    resolved = @account.conversations.resolved.where(id: resolved_ids).where.not(assignee_id: nil).group(:assignee_id).count
    in_progress = open_scope.where.not(assignee_id: nil).group(:assignee_id).count
    ids = (resolved.keys + in_progress.keys).uniq
    names = names_for(ids)

    ids.map do |id|
      done = resolved[id].to_i
      active = in_progress[id].to_i
      { id: id, name: names[id], resolved: done, in_progress: active, total: done + active }
    end.sort_by { |row| [-row[:total], row[:name].to_s] }
  end

  def conversations_in(band)
    records = open_scope.where(band_conditions[band])
                        .includes(:inbox, :assignee, contact: :company)
                        .order(Arel.sql('conversations.waiting_since ASC NULLS LAST'), :id)
                        .limit(@setting.list_limit).to_a
    previews = last_incoming_messages(records.map(&:id))

    records.map { |conversation| conversation_json(conversation, previews[conversation.id]) }
  end

  def conversation_json(conversation, preview)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      contact_name: conversation.contact&.name,
      company_name: conversation.contact&.company&.name,
      inbox_name: conversation.inbox&.name,
      channel_type: conversation.inbox&.channel_type,
      assignee_id: conversation.assignee_id,
      assignee_name: conversation.assignee&.name,
      waiting_since: conversation.waiting_since,
      last_message: preview&.truncate(PREVIEW_LENGTH)
    }
  end

  # A ultima mensagem DO CLIENTE de cada conversa, numa consulta so.
  def last_incoming_messages(conversation_ids)
    return {} if conversation_ids.empty?

    Message.where(conversation_id: conversation_ids, message_type: :incoming, private: false)
           .select('DISTINCT ON (conversation_id) conversation_id, content')
           .reorder(Arel.sql('conversation_id ASC, created_at DESC'))
           .to_a.to_h { |message| [message.conversation_id, message.content] }
  end

  def settings_json
    @setting.slice(:green_until_minutes, :orange_until_minutes, :refresh_seconds, :list_limit, :sound_enabled)
  end
end
