# Avisa por e-mail que a equipe mandou mensagem no chat do Portal - so na
# PRIMEIRA mensagem de uma sessao nova/reaberta (ver
# `ClientPortalChatListener`), para nao lotar a caixa do cliente numa
# conversa longa, de va-e-volta.
#
# Mesmo padrao do `ClientPasswordMailer`: ApplicationMailer (SMTP da conta,
# layout e resolvedor de templates da instalacao), portugues fixo (a Area do
# Cliente ainda nao tem preferencia de idioma por contato).
class ClientChatMailer < ApplicationMailer
  include ForcedPortugueseLocale

  def new_message(message)
    @message = message
    @contact = message.conversation.contact
    return if @contact&.email.blank?

    return unless smtp_config_set_or_development?

    mail(to: @contact.email, subject: I18n.t('client_chat_mailer.new_message.subject'))
  end
end
