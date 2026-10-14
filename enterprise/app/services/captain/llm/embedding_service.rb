class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  # All embedding vector columns (article_embeddings, knowledge_entries,
  # captain_faq_suggestions) are pgvector columns fixed at 1536 dimensions,
  # matching OpenAI's text-embedding-3-small. Any other embedding model must
  # be asked to emit the same size, or Postgres rejects the insert.
  VECTOR_DIMENSIONS = 1536

  DIMENSIONS_UNSUPPORTED_MESSAGE = "property 'dimensions' is unsupported".freeze

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
    @embedding_model = self.class.embedding_model
  end

  def self.embedding_model
    InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: @embedding_model, with_dimensions: true)
    return [] if content.blank?

    vectors = instrument_embedding_call(instrumentation_params(content, model)) do
      # Same reasoning as enterprise/app/models/concerns/agentable.rb: Chatwoot
      # only ever configures the openai_api_key/openai_api_base RubyLLM
      # settings, so pin provider explicitly instead of letting it guess from
      # the model name (e.g. "gemini-embedding-2" would otherwise be routed to
      # RubyLLM's native Gemini provider, which has no credentials here).
      params = { model: model, provider: :openai, assume_model_exists: true }
      params[:dimensions] = VECTOR_DIMENSIONS if with_dimensions
      RubyLLM.embed(content, **params).vectors
    end

    validate_dimensions!(vectors)
    vectors
  rescue RubyLLM::Error => e
    # "dimensions" e' um parametro so' da OpenAI (reduz o tamanho do vetor) -
    # alguns provedores OpenAI-compativeis (ex.: Groq) recusam a chamada
    # inteira por causa dele. Tenta de novo sem o parametro antes de desistir;
    # `validate_dimensions!` garante que o vetor que sobra ainda serve pra
    # coluna pgvector (sempre 1536), em vez de deixar um tamanho errado
    # quebrar na gravacao mais adiante.
    if with_dimensions && e.message.to_s.include?(DIMENSIONS_UNSUPPORTED_MESSAGE)
      Rails.logger.warn "Embedding API: retrying without 'dimensions' after provider conflict: #{e.message}"
      return get_embedding(content, model: model, with_dimensions: false)
    end

    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  # Sem isto, um vetor de tamanho errado (ex.: um provedor que ignora
  # "dimensions" e devolve o tamanho nativo do modelo) so' quebraria la' na
  # frente, ao gravar na coluna pgvector (fixa em 1536) - um erro bem mais
  # dificil de entender do que recusar aqui, com uma mensagem clara.
  def validate_dimensions!(vectors)
    size = vectors&.size
    return if size == VECTOR_DIMENSIONS

    raise EmbeddingsError, "Expected a #{VECTOR_DIMENSIONS}-dimension embedding, got #{size.inspect}"
  end

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
