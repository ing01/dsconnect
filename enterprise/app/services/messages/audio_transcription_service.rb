class Messages::AudioTranscriptionService
  attr_reader :attachment, :message, :account

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message&.account
  end

  # Antes exigia `captain_integration` (licenca Enterprise) + creditos de
  # resposta via `Llm::SpeechToTextService` - nesta instalacao self-hosted,
  # isso deixava a transcricao morta mesmo com uma chave OpenAI/Groq
  # configurada. Reaproveita o mesmo `Captain::AudioTranscriptionService` sem
  # licenca/creditos ja usado na abertura de ticket por IA do Portal.
  def perform
    return { error: 'Message not found' } if message.blank?

    blob = attachment.file&.blob
    return { error: 'No audio file attached' } if blob.blank?

    transcriptions = transcribe_audio(blob)
    Rails.logger.info "Audio transcription successful: #{transcriptions}"
    { success: true, transcriptions: transcriptions }
  end

  private

  def transcribe_audio(blob)
    transcribed_text = attachment.meta&.[]('transcribed_text') || ''
    return transcribed_text if transcribed_text.present?

    transcribed_text = blob.open do |file|
      response = Captain::AudioTranscriptionService.new(account: account, file: file).perform
      response[:error] ? '' : response[:text].to_s
    end

    update_transcription(transcribed_text)
    transcribed_text
  end

  def update_transcription(transcribed_text)
    return if transcribed_text.blank?

    attachment.update!(meta: { transcribed_text: transcribed_text })
    message.reload.send_update_event

    return unless ChatwootApp.advanced_search_allowed?

    message.reindex
  end
end
