module Concerns::Agentable
  extend ActiveSupport::Concern

  DEFAULT_TEMPERATURE = 0.5

  def agent
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: agent_tools,
      model: agent_model,
      # Chatwoot only ever configures the openai_api_key/openai_api_base
      # RubyLLM settings (see config/initializers/ai_agents.rb), so the
      # provider is always 'openai' - pin it explicitly instead of letting
      # the gem guess from the model name, which misreads a slash (e.g. a
      # custom/self-hosted model id like "openai/gpt-oss-20b" served by an
      # OpenAI-compatible endpoint such as Groq) as an OpenRouter model id.
      provider: :openai,
      assume_model_exists: true,
      temperature: temperature.presence&.to_f || DEFAULT_TEMPERATURE,
      response_schema: agent_response_schema
    )
  end

  def agent_instructions(context = nil, prompt_template: template_name)
    enhanced_context = prompt_context

    if context
      state = context.context[:state] || {}
      config = state[:assistant_config] || {}
      enhanced_context = enhanced_context.merge(
        current_time: format_current_time(state[:timezone]),
        conversation: state[:conversation] || {},
        contact: config['feature_contact_attributes'].present? ? state[:contact] : nil,
        campaign: state[:campaign] || {},
        message_length_limit: state[:message_length_limit]
      )
    end

    Captain::PromptRenderer.render(prompt_template, enhanced_context.with_indifferent_access)
  end

  def agent_model
    route = Llm::FeatureRouter.resolve(feature: 'assistant', account: account)
    return route[:model] if route[:source] == :account_override || account&.feature_enabled?('captain_integration_v2')

    installation_model.presence || route[:model]
  end

  private

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools
    []  # Default implementation, override if needed
  end

  def installation_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
  end

  def agent_response_schema
    Captain::ResponseSchema
  end

  def format_current_time(timezone)
    tz = ActiveSupport::TimeZone[timezone] if timezone.present?
    time = tz ? Time.current.in_time_zone(tz) : Time.current
    time.strftime('%A, %B %d, %Y %I:%M %p %Z')
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end
end
