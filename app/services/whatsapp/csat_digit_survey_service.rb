# Pesquisa de satisfacao por WhatsApp respondida digitando um numero de 1 a
# 5 (nao a UI de estrelas/emoji do widget - WhatsApp so tem texto). Reaproveita
# `CsatSurveyResponse` (mesmo model que a pesquisa nativa usa) para que a
# resposta apareca de graca nos relatorios de CSAT ja existentes; o que muda e
# so como a pesquisa e' enviada e como a resposta e' capturada.
#
# Independente da pesquisa nativa (`CsatSurveyService`/`inbox.csat_survey_enabled`):
# aquela depende de template aprovado na Meta/Twilio, que a AstereZap nao tem
# como oferecer. Por isso essa e' uma configuracao de conta separada
# (`Account#whatsapp_csat_survey_enabled`), editada na tela de Automacao do
# WhatsApp - e desliga sozinha se a pesquisa nativa da caixa ja estiver ativa,
# pra nunca mandar as duas.
class Whatsapp::CsatDigitSurveyService
  RATING_PATTERN = /\A[1-5]\z/

  pattr_initialize [:conversation!]

  def send_survey
    return unless should_send_survey?

    message = conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content_type: :input_csat,
      content: survey_message,
      # Sem esta marca, `MessageContentPresenter` troca o texto por engano -
      # ver o comentario em `should_append_survey_link?`.
      content_attributes: { whatsapp_csat_digit_survey: true }
    )
    terminate_live_flow_runs!
    message
  end

  def capture_response(message)
    return unless whatsapp_channel?

    survey_message_record = pending_survey_message
    return if survey_message_record.blank?

    rating = parse_rating(message.content)
    return if rating.blank?

    save_response!(survey_message_record, rating)
    send_thank_you!
  end

  private

  delegate :account, :inbox, to: :conversation

  def should_send_survey?
    whatsapp_channel? && account.whatsapp_csat_survey_enabled && !inbox.csat_survey_enabled? && !csat_already_sent?
  end

  def whatsapp_channel?
    inbox.channel_type == 'Channel::Whatsapp'
  end

  def csat_already_sent?
    conversation.messages.where(content_type: :input_csat).exists?
  end

  def survey_message
    account.whatsapp_csat_survey_message_or_default
  end

  # Uma conversa resolvida nao pode continuar com um fluxo de automacao "vivo"
  # esperando resposta - senao a resposta da pesquisa (um digito 1-5) corre o
  # risco de ser consumida pelo `AutomationRules::Flow::DispatcherService.resume`
  # como se fosse a resposta de uma etapa `ask` qualquer que ainda estivesse
  # parada, em vez de chegar em `capture_response` abaixo.
  def terminate_live_flow_runs!
    conversation.automation_flow_runs.live.find_each do |run|
      run.update!(status: :handed_off, current_step_id: nil, waiting_until: nil)
    end
  end

  # A pesquisa mais recente desta conversa que ainda nao tem resposta -
  # `left_joins` + `id: nil` acha exatamente isso sem precisar de uma coluna
  # "respondida" separada em Message.
  def pending_survey_message
    conversation.messages
                .where(content_type: :input_csat)
                .left_joins(:csat_survey_response)
                .where(csat_survey_responses: { id: nil })
                .order(created_at: :desc)
                .first
  end

  def parse_rating(content)
    value = content.to_s.strip
    return nil unless value.match?(RATING_PATTERN)

    value.to_i
  end

  # Mesmo padrao de `CsatSurveys::ResponseBuilder#process_csat_response` -
  # reaproveita o registro se por algum motivo ja existir, senao cria um novo.
  def save_response!(survey_message_record, rating)
    response = survey_message_record.csat_survey_response || CsatSurveyResponse.new(
      message_id: survey_message_record.id, account_id: survey_message_record.account_id,
      conversation_id: conversation.id, contact_id: conversation.contact_id,
      assigned_agent: conversation.assignee
    )
    response.rating = rating
    response.save!
  end

  def send_thank_you!
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: I18n.t('conversations.templates.whatsapp_csat_thank_you')
    )
  end
end
