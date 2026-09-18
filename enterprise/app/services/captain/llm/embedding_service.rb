class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  # All embedding vector columns (article_embeddings, knowledge_entries,
  # captain_faq_suggestions) are pgvector columns fixed at 1536 dimensions,
  # matching OpenAI's text-embedding-3-small. Any other embedding model must
  # be asked to emit the same size, or Postgres rejects the insert.
  VECTOR_DIMENSIONS = 1536

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
    @embedding_model = self.class.embedding_model
  end

  def self.embedding_model
    InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: @embedding_model)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content, model)) do
      # Same reasoning as enterprise/app/models/concerns/agentable.rb: Chatwoot
      # only ever configures the openai_api_key/openai_api_base RubyLLM
      # settings, so pin provider explicitly instead of letting it guess from
      # the model name (e.g. "gemini-embedding-2" would otherwise be routed to
      # RubyLLM's native Gemini provider, which has no credentials here).
      RubyLLM.embed(content, model: model, provider: :openai, assume_model_exists: true, dimensions: VECTOR_DIMENSIONS).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content, model)
    {
      span_name: 'llm.captain.embedding',
      model: model,
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end
