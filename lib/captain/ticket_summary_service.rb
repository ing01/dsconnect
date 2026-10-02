# Resume a(s) Conversa(s) vinculada(s) a um Ticket para virar a descricao
# dele - pedido da Ingrid para facilitar o agente descrever/fechar os
# proprios tickets, mesma ideia do "Resumir Conversa" do chat do atendente
# (ver Captain::SummaryService), mas por Ticket (que pode ter mais de uma
# Conversation vinculada, ver TicketConversation) em vez de por Conversation.
class Captain::TicketSummaryService < Captain::BaseTaskService
  pattr_initialize [:account!, :ticket!]

  def perform
    return { error: I18n.t('captain.ticket_summary.no_conversation') } if transcript.blank?

    make_api_call(
      feature: 'editor',
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: transcript }
      ]
    )
  end

  private

  def transcript
    @transcript ||= ticket.conversations
                          .order(:created_at)
                          .map { |conversation| conversation.to_llm_text(include_contact_details: false) }
                          .reject(&:blank?)
                          .join("\n\n---\n\n")
  end

  def system_prompt
    <<~PROMPT
      #{prompt_from_file('ticket_summary')}

      Reply in #{account.locale_english_name}.
    PROMPT
  end

  def event_name
    'ticket_summary'
  end

  def use_account_openai_hook?
    true
  end
end
