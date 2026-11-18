# Transforma uma conversa em UMA linha do relatorio "Chat detalhado" (e nos numeros que o
# resumo precisa).
#
# Uma conversa conta como ATENDIDA quando alguem a assumiu: tem responsavel, ou foi
# atribuida, ou ja recebeu resposta de um atendente. Finalizada sem isso, e' um chat
# CANCELADO ("Finalizado sem atendimento").
class ChatDetailReport::EntryBuilder
  # O que cada conversa entrega para a linha e para o resumo.
  Entry = Struct.new(:row, :attended, :finished, :duration, :wait, :first_contact, :contact_id, :ticket_ids)

  STATUS_LABELS = { 'open' => 'Aberto', 'resolved' => 'Fechado', 'pending' => 'Pendente', 'snoozed' => 'Adiado' }.freeze
  CANCELLED_LABEL = 'Finalizado sem atendimento'.freeze

  ORIGIN_LABELS = {
    'Channel::WebWidget' => 'Chat do site', 'Channel::Email' => 'E-mail', 'Channel::Api' => 'API',
    'Channel::Telegram' => 'Telegram', 'Channel::Sms' => 'SMS', 'Channel::FacebookPage' => 'Facebook',
    'Channel::Instagram' => 'Instagram', 'Channel::Line' => 'Line', 'Channel::TwitterProfile' => 'Twitter'
  }.freeze

  # `facts`: { first_messages: {conversation_id => Message}, assignments: {conversation_id => {first:, count:}} }
  pattr_initialize [:zone!, :facts!]

  def build(conversation)
    assignment = facts[:assignments][conversation.id]
    attended = attended?(conversation, assignment)
    times = times_for(conversation, assignment, attended)
    row = identity_cells(conversation).merge(time_cells(conversation, times, attended))
                                      .merge(people_cells(conversation)).merge(ticket_cells(conversation))

    Entry.new(row, attended, times[:finished].present?, times[:duration], times[:wait],
              first_contact?(conversation, attended, assignment), conversation.contact_id, conversation.tickets.map(&:id))
  end

  private

  def attended?(conversation, assignment)
    conversation.assignee_id.present? || assignment.present? || conversation.first_reply_created_at.present?
  end

  # Sem registro de atribuicao (conversa que ja nasceu com responsavel), vale o primeiro
  # contato do atendente - ou, na falta dele, a abertura.
  def times_for(conversation, assignment, attended)
    started = conversation.created_at
    assumed = attended ? (assignment&.dig(:first) || conversation.first_reply_created_at || started) : nil
    finished = conversation.resolved? ? (conversation.status_changed_at || conversation.updated_at) : nil
    {
      started: started, assumed: assumed, finished: finished,
      wait: assumed ? [assumed - started, 0].max.to_i : 0,
      duration: assumed && finished ? [finished - assumed, 0].max.to_i : 0
    }
  end

  # Resolvido sem voltar para a fila: assumido uma vez so'.
  def first_contact?(conversation, attended, assignment)
    attended && conversation.resolved? && (assignment&.dig(:count) || 0) <= 1
  end

  def identity_cells(conversation)
    {
      id: conversation.display_id, client: conversation.contact&.company&.name,
      origin: origin_label(conversation.inbox), started_by: started_by(facts[:first_messages][conversation.id]),
      status: STATUS_LABELS[conversation.status], rating: conversation.csat_survey_response&.rating
    }
  end

  def time_cells(conversation, times, attended)
    finished = times[:finished]
    {
      started_at: format_time(times[:started]), assumed_at: assumed_label(attended, times[:assumed], finished),
      first_message_at: format_time(conversation.first_reply_created_at), updated_at: format_time(conversation.updated_at),
      finished_at: format_time(finished), duration: finished ? hms(times[:duration]) : nil,
      wait: attended || finished ? hms(times[:wait]) : nil
    }
  end

  def people_cells(conversation)
    contact = conversation.contact
    {
      assignee: conversation.assignee&.name, group: conversation.team&.name, department: conversation.queue&.name,
      contact: contact&.name, phone: contact&.phone_number.to_s.delete('+').presence
    }
  end

  # Os tickets ligados, e a classificacao do primeiro que tiver Catalogo.
  def ticket_cells(conversation)
    item = conversation.tickets.filter_map(&:service_catalog_item).first
    {
      ticket: conversation.tickets.map(&:display_id).join('; ').presence,
      catalog: item&.service_catalog&.name, area: item&.service_catalog_area&.name, item: item&.name
    }
  end

  def assumed_label(attended, assumed, finished)
    return format_time(assumed) if attended

    finished ? CANCELLED_LABEL : nil
  end

  def started_by(first_message)
    return unless first_message
    return 'Solicitante' if first_message.message_type.to_i.zero?

    first_message.sender_type == 'AgentBot' ? 'Bot' : 'Atendente'
  end

  def origin_label(inbox)
    return if inbox.blank?
    return whatsapp_label(inbox.channel) if inbox.channel_type == 'Channel::Whatsapp'

    ORIGIN_LABELS[inbox.channel_type] || inbox.name
  end

  def whatsapp_label(channel)
    channel&.provider == 'whatsapp_cloud' ? 'WhatsApp Cloud' : 'WhatsApp'
  end

  def format_time(time)
    return if time.blank?

    time.in_time_zone(zone).strftime('%d/%m/%Y %H:%M')
  end

  # Horas sem limite de 24: "3173:10:09".
  def hms(seconds)
    ChatDetailReport::SummaryAccumulator.hms(seconds)
  end
end
