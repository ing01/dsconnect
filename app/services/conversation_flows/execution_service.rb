# Advances a conversation through its assigned Chatbot's ConversationFlow, one incoming
# message at a time. Mirrors the same bot-assignment/handoff mechanism Captain already
# uses (Conversation#assignee_agent_bot, Conversation#bot_handoff!) instead of a parallel
# system, so a "flow" AgentBot behaves exactly like any other bot to the rest of the app.
class ConversationFlows::ExecutionService
  pattr_initialize [:message!]

  MAX_STEPS_PER_PASS = 15
  MAX_RETRIES = 2

  delegate :conversation, to: :message

  def perform
    return unless message.incoming?
    return unless conversation.assignee_agent_bot&.flow?
    return unless conversation.pending?

    flow = conversation.assignee_agent_bot.conversation_flow
    return if flow.blank? || !flow.active?

    state = conversation.conversation_flow_state
    return if state.present? && !state.in_progress?

    I18n.with_locale(conversation.account.locale) do
      if state.present?
        process_reply(state)
      else
        run_steps(start_flow(flow))
      end
    end
  end

  private

  def start_flow(flow)
    conversation.create_conversation_flow_state!(
      account_id: conversation.account_id,
      conversation_flow: flow,
      current_step: flow.first_step,
      started_at: Time.current
    )
  end

  def process_reply(state)
    current_step = state.current_step
    return run_steps(state) if current_step.blank? || !current_step.awaiting_reply?

    return advance_after_free_text(state, current_step) if current_step.ask_question?

    match = ConversationFlows::StepMatcherService.new(step: current_step, reply: message.content.to_s).perform
    return handle_no_match(state, current_step) if match == :no_match

    state.update!(current_step: match, retry_count: 0)
    run_steps(state)
  end

  def advance_after_free_text(state, current_step)
    state.update!(current_step: current_step.next_step, retry_count: 0)
    run_steps(state)
  end

  def handle_no_match(state, step)
    if state.retry_count >= MAX_RETRIES
      complete!(state)
      conversation.bot_handoff!
      return
    end

    state.increment!(:retry_count)
    post_prompt(step, prefix: I18n.t('conversations.flow.no_match_prefix'))
  end

  def run_steps(state)
    step = state.current_step
    steps_run = 0

    while step.present? && steps_run < MAX_STEPS_PER_PASS
      steps_run += 1

      if step.awaiting_reply?
        state.update!(current_step: step)
        post_prompt(step)
        return
      end

      execute_action(step)

      if step.terminal?
        complete!(state, current_step: step)
        conversation.bot_handoff!
        return
      end

      step = step.next_step
    end

    # Safety net: hit the step cap (or a broken chain) without an explicit end_flow -
    # hand off rather than leave the conversation silently stuck on a bot.
    complete!(state, current_step: step)
    conversation.bot_handoff!
  end

  def execute_action(step)
    case step.step_type
    when 'send_message'
      post_message(step.content)
    when 'transfer_team'
      conversation.update!(team_id: step.options['team_id'])
    when 'transfer_queue'
      conversation.update!(queue_id: step.options['queue_id'])
    when 'add_label'
      conversation.add_labels(Array(step.options['labels']))
    when 'set_priority'
      conversation.update!(priority: step.options['priority'])
    when 'create_ticket'
      create_ticket_from(step)
    end
  end

  def create_ticket_from(step)
    team = conversation.team
    return if team.blank?

    ticket = team.tickets.create!(
      account_id: conversation.account_id,
      title: conversation.contact&.name.presence || "Conversa ##{conversation.display_id}",
      description: message.content.presence || '-',
      priority: conversation.priority.presence || 'medium',
      ticket_column: team.ticket_columns.order(:position).first,
      ticket_category_id: step.options['ticket_category_id'],
      contact: conversation.contact,
      company: conversation.contact&.company
    )
    TicketConversation.create!(account_id: conversation.account_id, ticket: ticket, conversation: conversation)
  rescue StandardError => e
    Rails.logger.error("ConversationFlows::ExecutionService failed to create ticket for conversation #{conversation.id}: #{e.message}")
  end

  def post_prompt(step, prefix: nil)
    content = [prefix, step.content].compact.join("\n\n")

    if step.present_options?
      items = step.items.map { |item| { title: item['title'], value: item['value'] } }
      post_message(content, content_type: :input_select, content_attributes: { items: items })
    else
      post_message(content)
    end
  end

  def post_message(content, content_type: :text, content_attributes: {})
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: conversation.assignee_agent_bot,
      content: content,
      content_type: content_type,
      content_attributes: content_attributes
    )
  end

  def complete!(state, current_step: nil)
    state.update!(status: :completed, completed_at: Time.current, current_step: current_step)
  end
end
