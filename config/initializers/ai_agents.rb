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
        # Mesma convencao de lib/captain/base_task_service.rb#api_base e dos
        # demais pontos que leem CAPTAIN_OPEN_AI_ENDPOINT: o campo guarda so a
        # raiz do provider (ex.: Groq e' "https://api.groq.com/openai"), sem
        # o "/v1" - e' este initializer que completa. `delete_suffix` torna
        # isto tolerante a quem digitar o "/v1" de qualquer jeito (o `/v1`
        # nao dobra).
        base = api_endpoint.chomp('/').delete_suffix('/v1')
        config.openai_api_base = "#{base}/v1"
      end
      config.default_model = model
      config.debug = false
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
