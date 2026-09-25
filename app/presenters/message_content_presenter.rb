class MessageContentPresenter < SimpleDelegator
  def outgoing_content
    Messages::MarkdownRendererService.new(
      content_with_survey_link,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render
  end

  def webhook_content
    Messages::WebhookContentNormalizer.normalize(content_with_survey_link)
  end

  private

  def content_with_survey_link
    if should_append_survey_link?
      survey_link = survey_url(conversation.uuid)
      custom_message = inbox.csat_config&.dig('message')
      custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
    else
      content
    end
  end

  # A pesquisa por digito do WhatsApp (`Whatsapp::CsatDigitSurveyService`) usa
  # o mesmo `content_type: :input_csat` da pesquisa nativa, mas ja escreve o
  # texto pronto (pede pra responder 1-5) - sem esta excecao, este metodo
  # trocava esse texto pelo link da pesquisa nativa (que nem esta habilitada
  # nesta conta), mandando a mensagem errada pro cliente no WhatsApp.
  def should_append_survey_link?
    input_csat? && !inbox.web_widget? && !digit_survey?
  end

  def digit_survey?
    content_attributes['whatsapp_csat_digit_survey'].present?
  end

  def survey_url(conversation_uuid)
    "#{ENV.fetch('FRONTEND_URL', nil)}/survey/responses/#{conversation_uuid}"
  end
end
