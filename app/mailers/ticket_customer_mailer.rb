# Messages a ticket sends TO the customer. Built on ApplicationMailer so it
# inherits the account's SMTP configuration, the mailer layout and the database
# template resolver, rather than standing up any e-mail infrastructure of its
# own.
#
# The two events are deliberately separate actions: an agent writing to the
# customer and the closing of the ticket are different messages, and sending one
# then the other produces two distinct e-mails.
class TicketCustomerMailer < ApplicationMailer
  # Vai para o cliente: portugues sempre, independente da conta.
  include ForcedPortugueseLocale

  # Ordinary correspondence from the Comunicacao com cliente area.
  def customer_message(communication)
    prepare(communication)
    return unless smtp_config_set_or_development?

    mail(to: communication.to_email, subject: communication.subject)
  end

  # The closing notice. Left as it was on purpose - it is its own message.
  def closing_communication(communication)
    prepare(communication)
    return unless smtp_config_set_or_development?

    mail(to: communication.to_email, subject: communication.subject)
  end

  private

  def prepare(communication)
    @communication = communication
    @ticket = communication.ticket
    @contact = communication.contact
    @company = @ticket.company
    # O nome do atendente aparece sempre - a assinatura customizada
    # (`message_signature`) e' um extra opcional por cima disso, nao um
    # substituto: sem ela, o cliente ainda precisa saber quem atendeu.
    @agent_name = communication.user&.name
    # Only when the sender actually has one; a blank signature must not leave an
    # empty block at the end of the message.
    @signature = communication.user&.message_signature.presence
    # A ticket can exist without an Empresa, and "da empresa " with nothing
    # after it reads as a bug.
    @greeting_key = @company&.name.present? ? '.greeting' : '.greeting_without_company'
    @sent_at = local_time(communication)
  end

  # O padrao do app e UTC (`config.time_zone` nunca foi definido) - sem uma
  # conversao aqui, o horario no e-mail sai 3h adiantado do Brasil sempre que
  # a conta nao tiver `reporting_timezone` configurado (a maioria nao tem; e
  # opt-in, via rake task). O cliente nao escolhe fuso horario nenhum, entao o
  # padrao e sempre Brasilia - a conta so' sobrescreve quando tem outro de
  # verdade.
  def local_time(communication)
    moment = communication.sent_at || Time.zone.now
    zone = communication.account&.reporting_timezone.presence || 'America/Sao_Paulo'
    moment = moment.in_time_zone(zone) if ActiveSupport::TimeZone[zone].present?
    # Formatted here rather than through a locale `time.formats` entry: these
    # files have no such section, and adding one would change how dates render
    # elsewhere.
    moment.strftime('%d/%m/%Y %H:%M')
  end
end
