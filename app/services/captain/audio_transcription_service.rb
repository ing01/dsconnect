# Transcreve um audio curto (voz gravada no Portal do Cliente, na abertura de
# ticket por IA) usando a mesma credencial OpenAI que o Captain ja resolve
# (Hook da conta ou InstallationConfig) - sem depender do modulo Enterprise
# (Llm::SpeechToTextService), que fica atras de `captain_integration` e de
# creditos de resposta que essa tela nem usa.
class Captain::AudioTranscriptionService < Captain::BaseTaskService
  MODEL = 'whisper-1'.freeze

  pattr_initialize [:account!, :file!]

  def perform
    return { error: I18n.t('captain.api_key_missing'), error_code: 401 } unless api_key_configured?

    response = client.audio.transcribe(
      parameters: { model: transcription_model, file: file.to_io, temperature: 0.0 }
    )
    { text: response['text'] }
  rescue StandardError => e
    { error: e.message }
  end

  private

  # Sem isto, so a chave global do servidor (InstallationConfig, so por SSH)
  # valeria - a chave configurada pela propria conta em Configuracoes >
  # Integracoes > OpenAI (tela comum, sem precisar de acesso ao servidor)
  # ficaria cadastrada e mesmo assim nunca seria usada de verdade.
  def use_account_openai_hook?
    true
  end

  # Whisper (`whisper-1`) e' da OpenAI - providers OpenAI-compatible (ex.:
  # Groq) usam outro nome de modelo pra transcricao (ex.: `whisper-large-v3`).
  # CAPTAIN_TRANSCRIPTION_MODEL (Super Admin > Configuracoes > Captain)
  # permite trocar sem precisar mexer em codigo.
  def transcription_model
    InstallationConfig.find_by(name: 'CAPTAIN_TRANSCRIPTION_MODEL')&.value.presence || MODEL
  end

  def event_name
    'ticket_draft_audio_transcription'
  end

  def client
    OpenAI::Client.new(access_token: api_key, uri_base: api_base, log_errors: Rails.env.development?)
  end
end
