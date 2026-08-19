# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL
  api_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value || LlmConstants::OPENAI_API_ENDPOINT

  if api_key.present?
    Agents.configure do |config|
      config.openai_api_key = api_key
      if api_endpoint.present?
        # CAPTAIN_OPEN_AI_ENDPOINT already includes any provider-specific path
        # (e.g. Groq's "https://api.groq.com/openai/v1") - matches the convention
        # used in lib/llm/config.rb. Don't append /v1 again here.
        config.openai_api_base = api_endpoint.chomp('/')
      end
      config.default_model = model
      config.debug = false
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
