module AccountSettingsSchema
  extend ActiveSupport::Concern

  CAPTAIN_MODEL_PROPERTIES = Llm::Models.model_feature_keys.index_with { { 'type': %w[string null] } }.freeze
  CAPTAIN_FEATURE_PROPERTIES = Llm::Models.feature_keys.index_with { { 'type': %w[boolean null] } }.freeze

  SETTINGS_PARAMS_SCHEMA = {
    'type': 'object',
    'properties':
      {
        'auto_resolve_after': { 'type': %w[integer null], 'minimum': 10, 'maximum': 1_439_856 },
        'auto_resolve_message': { 'type': %w[string null] },
        'auto_resolve_ignore_waiting': { 'type': %w[boolean null] },
        'audio_transcriptions': { 'type': %w[boolean null] },
        'auto_resolve_label': { 'type': %w[string null] },
        'keep_pending_on_bot_failure': { 'type': %w[boolean null] },
        'captain_auto_resolve_mode': { 'type': %w[string null], 'enum': ['evaluated', 'legacy', 'disabled', nil] },
        'captain_false_promise_harness_enabled': { 'type': %w[boolean null] },
        'conversation_required_attributes': {
          'type': %w[array null],
          'items': { 'type': 'string' }
        },
        'captain_models': {
          'type': %w[object null],
          'properties': CAPTAIN_MODEL_PROPERTIES,
          'additionalProperties': false
        },
        'captain_features': {
          'type': %w[object null],
          'properties': CAPTAIN_FEATURE_PROPERTIES,
          'additionalProperties': false
        },
        'helpdesk_whatsapp_flow_enabled': { 'type': %w[boolean null] },
        'helpdesk_ai_resolve_levels': {
          'type': %w[array null],
          'items': { 'type': 'integer', 'minimum': 1, 'maximum': 3 }
        },
        'helpdesk_default_priority_on_ai_failure': {
          'type': %w[string null], 'enum': %w[baixa media alta] + [nil]
        },
        'helpdesk_open_ticket_window_days': { 'type': %w[integer null], 'minimum': 1 },
        'helpdesk_level_3to5_team_id': { 'type': %w[integer null] },
        'helpdesk_default_queue_id': { 'type': %w[integer null] },
        'priority_threshold_medium_min': { 'type': %w[number null], 'minimum': 0 },
        'priority_threshold_high_min': { 'type': %w[number null], 'minimum': 0 },
        'whatsapp_automation_test_mode_number': { 'type': %w[string null] }
      },
    'required': [],
    'additionalProperties': true
  }.to_json.freeze
end
