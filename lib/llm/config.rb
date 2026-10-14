require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    # Modelo de chat configurado pela conta/servidor (CAPTAIN_OPEN_AI_MODEL,
    # mesma config usada em Super Admin > Configuracoes > Captain) - usado
    # para trocar de provider (ex.: Groq) sem precisar mexer em codigo, desde
    # que o endpoint (CAPTAIN_OPEN_AI_ENDPOINT) tambem aponte pra la.
    def chat_model
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || DEFAULT_MODEL
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = normalized_openai_endpoint if openai_endpoint.present?
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end

    # O campo guarda so a raiz do provider (ex.: Groq e' "https://api.groq.com/openai"),
    # sem o "/v1" - mesma convencao de `Captain::BaseTaskService#api_base`.
    # `delete_suffix` torna isto tolerante a quem digitar o "/v1" de qualquer
    # jeito (o "/v1" nao dobra).
    def normalized_openai_endpoint
      "#{openai_endpoint.chomp('/').delete_suffix('/v1')}/v1"
    end
  end
end
