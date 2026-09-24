module Enterprise::Api::V1::AccountsSettings
  def create
    super
    record_marketing_attribution
  end

  private

  # The upgrade banner is a self-hosted nudge; the managed cloud instance is always current.
  def latest_chatwoot_version
    return if ChatwootApp.chatwoot_cloud?

    super
  end

  def record_marketing_attribution
    return if current_user.present?
    return if @account.blank?

    Internal::Accounts::MarketingAttributionService.new(account: @account, cookies: cookies).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  def permitted_settings_attributes
    super + [
      { conversation_required_attributes: [] },
      :helpdesk_whatsapp_flow_enabled,
      { helpdesk_ai_resolve_levels: [] },
      :helpdesk_default_priority_on_ai_failure,
      :helpdesk_open_ticket_window_days,
      :helpdesk_level_3to5_team_id,
      :helpdesk_default_queue_id,
      :helpdesk_queue_low_id,
      :helpdesk_queue_high_id,
      :helpdesk_support_phone_number,
      :priority_threshold_medium_min,
      :priority_threshold_high_min,
      :whatsapp_automation_test_mode_number,
      :whatsapp_auto_assignment_enabled,
      :whatsapp_auto_assignment_max_open_chats,
      { whatsapp_auto_assignment_excluded_agent_ids: [] },
      :whatsapp_csat_survey_enabled,
      :whatsapp_csat_survey_message
    ]
  end
end
