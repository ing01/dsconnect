# O texto que a IA le para escrever o "Resumo do cliente". Leva as notas privadas
# (e' onde a equipe registra o contexto), mas nao leva e-mail, telefone,
# documentos, credenciais nem valores de contrato.
#
# Devolve nil quando nao ha historico: nao vale gastar uma chamada de IA.
class CustomerBriefing::MaterialBuilder
  # O provedor limita o tamanho de cada chamada; o que nao couber fica de fora, na
  # ordem de importancia de `blocks`.
  MAX_CHARS = 24_000
  CONVERSATION_MAX_CHARS = 6_000
  MESSAGES_PER_CONVERSATION = 30
  MESSAGE_LENGTH = 500
  DESCRIPTION_LENGTH = 400
  NOTE_LENGTH = 500

  pattr_initialize [:sources!]

  def perform
    return if history.empty?

    history.each_with_object([header]) do |block, parts|
      parts << block if parts.sum(&:length) + block.length <= MAX_CHARS
    end.join("\n\n")
  end

  private

  delegate :conversation, :contact, :company, to: :sources

  def history
    @history ||= [
      notes_block,
      current_conversation_block,
      *conversation_blocks(sources.contact_conversations, 'Conversa anterior deste contato'),
      tickets_block,
      *conversation_blocks(sources.colleague_conversations, 'Conversa de outro contato da mesma empresa')
    ].compact
  end

  def header
    [company_lines, "Contato atendido: #{contact.name}"].compact.join("\n\n")
  end

  def company_lines
    return unless company

    lines(
      'Empresa' => company.name,
      'Situação' => company.status == 'active' ? 'ativa' : 'inativa',
      'Bloqueada' => (company.blocked ? 'sim' : nil),
      'Nível' => company.classification_level,
      'Categoria' => company.company_category&.name,
      'Módulos' => company.system_modules.map(&:name).sort.join(', '),
      'Usa o sistema desde' => company.system_started_on
    )
  end

  def lines(values)
    values.filter_map { |label, value| "#{label}: #{value}" if value.present? }.join("\n")
  end

  def notes_block
    notes = sources.notes.map { |note| "- #{note.content.to_s.truncate(NOTE_LENGTH)}" }
    "Notas da equipe sobre o contato:\n#{notes.join("\n")}" if notes.any?
  end

  def tickets_block
    tickets = sources.tickets.map { |ticket| ticket_lines(ticket) }
    "Tickets (os abertos primeiro):\n#{tickets.join("\n")}" if tickets.any?
  end

  def ticket_lines(ticket)
    facts = [ticket.status, ticket.priority, ticket.team&.name, ticket.contact&.name, ticket.created_at.to_date]
    line = "- ##{ticket.display_id} [#{facts.compact.join(', ')}] #{ticket.title}"
    return line if ticket.description.blank?

    "#{line}\n  Descrição: #{ticket.description.squish.truncate(DESCRIPTION_LENGTH)}"
  end

  # Em caixa de conversa unica o historico inteiro do cliente vive na conversa
  # aberta - sem ela nao haveria o que resumir.
  def current_conversation_block
    return unless conversation.inbox.lock_to_single_conversation?

    conversation_block(conversation, 'Conversa atual')
  end

  def conversation_blocks(list, title)
    list.map { |item| conversation_block(item, title) }
  end

  # As mensagens mais recentes que couberem, em ordem de leitura.
  def conversation_block(item, title)
    selected = []
    size = 0
    recent_messages(item).each do |message|
      line = message_line(message)
      next if line.blank?
      break if size + line.length > CONVERSATION_MAX_CHARS

      selected.unshift(line)
      size += line.length
    end
    return if selected.empty?

    heading = "#{title} ##{item.display_id} (#{item.contact&.name}, #{item.status}, #{item.last_activity_at.to_date}):"
    [heading, *selected].join("\n")
  end

  def recent_messages(item)
    item.messages
        .where(message_type: [:incoming, :outgoing])
        .reorder(created_at: :desc, id: :desc)
        .limit(MESSAGES_PER_CONVERSATION)
  end

  def message_line(message)
    content = message.content_for_llm
    return if content.blank?

    author = if message.incoming?
               'Cliente'
             elsif message.private?
               '[Nota interna] Equipe'
             else
               'Equipe'
             end
    "#{author}: #{content.squish.truncate(MESSAGE_LENGTH)}"
  end
end
