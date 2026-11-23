class AutomationRules::ActionService < ActionService
  # So' o chat do Portal do Cliente precisa do atraso: a automacao roda no
  # mesmo instante em que a conversa nasce (primeira mensagem do cliente), e
  # o navegador do outro lado so' assina o canal em tempo real DEPOIS de
  # receber a resposta daquele envio - sem o atraso, a mensagem existia no
  # servidor mas so' aparecia na tela depois de um F5 (ver
  # `AutomationRules::SendMessageJob`). Os demais canais (WhatsApp, e-mail,
  # Website Widget) continuam recebendo na hora, como sempre.
  SEND_MESSAGE_DELAY = 2.5.seconds

  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    unless client_portal_conversation?
      params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
      Messages::MessageBuilder.new(nil, @conversation, params).perform
      return
    end

    AutomationRules::SendMessageJob
      .set(wait: SEND_MESSAGE_DELAY)
      .perform_later(rule_id: @rule.id, conversation_id: @conversation.id, content: message[0])
  end

  # A mesma marca que identifica a caixa de entrada do Portal do Cliente em
  # `Inboxes::EnsureClientPortalInboxService` - sem tabela nova, so' um Channel::Api
  # comum com esse atributo.
  def client_portal_conversation?
    channel = @conversation.inbox.channel
    channel.respond_to?(:additional_attributes) &&
      channel.additional_attributes.is_a?(Hash) &&
      channel.additional_attributes[Inboxes::EnsureClientPortalInboxService::MARKER_KEY] == true
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end
end
