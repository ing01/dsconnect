# A redefinicao de senha da Area do Cliente.
#
# Existe separado do `Devise::Mailer` porque o destino do link nao e o mesmo: o
# usuario interno volta para o painel, e o contato volta para a tela propria da
# Area do Cliente. O `Devise::Mailer` monta a URL com `edit_password_url(resource)`,
# que exige um `devise_for :contacts` que nao existe - e nao deve existir, porque
# o contato nao tem sessao de Devise, e sim o AccessToken.
#
# Sobre ApplicationMailer para herdar o SMTP da conta, o layout e o resolvedor de
# templates, como o TicketCustomerMailer ja faz.
class ClientPasswordMailer < ApplicationMailer
  include ForcedPortugueseLocale

  def reset_password_instructions(contact, token)
    @contact = contact
    @token = token
    # O prazo vem do proprio Devise, e nao de um numero repetido aqui: mudar
    # `reset_password_within` passa a valer na mensagem no mesmo instante.
    @validade_em_horas = (Devise.reset_password_within / 1.hour).to_i

    return unless smtp_config_set_or_development?

    mail(to: @contact.email, subject: I18n.t('client_password_mailer.reset_password_instructions.subject'))
  end
end
