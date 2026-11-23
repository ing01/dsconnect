# Monta o payload do Painel de Conversas: cada conversa ABERTA cai em exatamente
# uma faixa, pelo tempo que o cliente espera resposta (`waiting_since`):
#
#   verde    - o agente ja respondeu (waiting_since vazio) OU espera ate T1
#   laranja  - espera acima de T1 e ate T2
#   vermelho - espera acima de T2
#
# Conversa sem agente (ou com bot) entra na faixa pelo tempo, como qualquer outra.
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
      by_inbox: breakdown(:inbox_id),
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
      green_limit = threshold(@setting.green_until_minutes)
      orange_limit = threshold(@setting.orange_until_minutes)
      {
        green: sanitize('conversations.waiting_since IS NULL OR conversations.waiting_since > ?', green_limit),
        orange: sanitize('conversations.waiting_since <= ? AND conversations.waiting_since > ?', green_limit, orange_limit),
        red: sanitize('conversations.waiting_since <= ?', orange_limit)
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
    green, orange, red, total, unassigned, longest, average = open_scope.pick(
      *(band_counts_sql + [
        'COUNT(*)',
        'COUNT(*) FILTER (WHERE conversations.assignee_id IS NULL)',
        sanitize('EXTRACT(EPOCH FROM (CAST(? AS timestamp) - MIN(conversations.waiting_since)))', @now),
        sanitize('AVG(EXTRACT(EPOCH FROM (CAST(? AS timestamp) - conversations.waiting_since)))', @now)
      ]).map { |sql| Arel.sql(sql) }
    )

    paused = @account.conversations.where(status: %i[pending snoozed]).group(:status).count

    {
      green: green.to_i, orange: orange.to_i, red: red.to_i, total: total.to_i,
      unassigned: unassigned.to_i,
      paused: paused['pending'].to_i, snoozed: paused['snoozed'].to_i,
      longest_wait_seconds: longest&.to_i, average_wait_seconds: average&.to_i
    }
  end

  # Quantas conversas de cada faixa por agente / por caixa de entrada.
  def breakdown(column)
    rows = open_scope.group(column).pluck(Arel.sql(column.to_s), *band_counts_sql.map { |sql| Arel.sql(sql) })
    names = names_for(column, rows.map(&:first).compact)

    rows.map do |key, green, orange, red|
      { id: key, name: names[key], green: green, orange: orange, red: red, total: green + orange + red }
    end.sort_by { |row| [-row[:red], -row[:orange], -row[:total]] }
  end

  def names_for(column, ids)
    return {} if ids.empty?

    column == :assignee_id ? User.where(id: ids).pluck(:id, :name).to_h : @account.inboxes.where(id: ids).pluck(:id, :name).to_h
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
           .order(:conversation_id, created_at: :desc)
           .to_h { |message| [message.conversation_id, message.content] }
  end

  def settings_json
    @setting.slice(:green_until_minutes, :orange_until_minutes, :refresh_seconds, :list_limit, :sound_enabled)
  end
end
