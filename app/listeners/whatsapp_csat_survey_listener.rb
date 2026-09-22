# Pesquisa de satisfacao por digito (1-5) no WhatsApp - ver
# Whatsapp::CsatDigitSurveyService pela logica de verdade; este listener so
# liga os eventos certos a ela. Independente do CsatSurveyListener nativo
# (que depende de template aprovado na Meta/Twilio).
class WhatsappCsatSurveyListener < BaseListener
  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless conversation.resolved?

    I18n.with_locale(conversation.account.locale) do
      Whatsapp::CsatDigitSurveyService.new(conversation: conversation).send_survey
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.incoming?

    I18n.with_locale(message.account.locale) do
      Whatsapp::CsatDigitSurveyService.new(conversation: message.conversation).capture_response(message)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message&.account).capture_exception
  end
end
