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
      parameters: { model: MODEL, file: file.to_io, temperature: 0.0 }
    )
    { text: response['text'] }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def event_name
    'ticket_draft_audio_transcription'
  end

  def client
    OpenAI::Client.new(access_token: api_key, uri_base: api_base, log_errors: Rails.env.development?)
  end
end
