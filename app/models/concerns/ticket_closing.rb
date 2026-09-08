# What a ticket needs before an agent may close it: a service catalogue
# classification, and a closing message that actually reached the customer.
#
# Enforced in the model rather than in the controller, so every path that closes
# a ticket on an agent's behalf goes through it - the detail page, the Kanban
# card and a transfer that sets the status to `closed` all land here.
#
# `Tickets::MergeService` is the one caller that closes a ticket without these:
# grouping is an administrative close, not a finished attendance, so it passes
# `skip_requirements: true` explicitly.
module TicketClosing
  extend ActiveSupport::Concern

  # Raised instead of returning false, so a caller cannot close a ticket by
  # ignoring a return value.
  class NotAllowed < StandardError
    attr_reader :missing

    def initialize(missing)
      @missing = missing
      super("Ticket cannot be closed: #{missing.join(', ')}")
    end
  end

  MISSING_CATEGORY = 'ticket_category'.freeze
  MISSING_CATALOG = 'service_catalog'.freeze
  MISSING_COMMUNICATION = 'customer_communication'.freeze
  MISSING_CONTACT_EMAIL = 'contact_email'.freeze

  included do
    belongs_to :service_catalog_item, optional: true
    has_many :ticket_customer_communications, dependent: :destroy
  end

  # Records the classification and the history entry in one step, so the
  # Historico shows the full path rather than an opaque id.
  def classify!(item, user = Current.user)
    return if service_catalog_item_id == item&.id

    transaction do
      previous = service_catalog_item
      update!(service_catalog_item: item)
      ticket_activities.create!(
        account_id: account_id, user: user, activity_type: :classified,
        previous_value: previous&.full_path&.join(' > '),
        new_value: item&.full_path&.join(' > '),
        meta: { service_catalog_item_id: item&.id }.compact
      )
    end
  end

  def classified?
    service_catalog_item_id.present?
  end

  def closing_communication_sent?
    ticket_customer_communications.closing_sent.exists?
  end

  # The address the closing message would go to. Nil is itself a blocker: a
  # ticket whose requester has no e-mail cannot be closed, and saying so is more
  # useful than failing at send time.
  def customer_email
    requester_contact&.email.presence
  end

  # A comunicacao de fechamento so pode ser exigida onde ela consegue sair.
  #
  # Sem SMTP configurado - o caso de homologacao - nao ha como enviar nada, e
  # exigir o envio tranca o ticket sem que exista acao capaz de destrancar. A
  # regra volta sozinha quando SMTP_ADDRESS for definido em producao: nao ha
  # chave para lembrar de desligar depois.
  #
  # Difere do `smtp_config_set_or_development?` do ApplicationMailer de
  # proposito: la o desenvolvimento conta como configurado para as previas de
  # e-mail funcionarem, e aqui o que importa e a mensagem chegar ao cliente.
  def customer_email_deliverable?
    ENV.fetch('SMTP_ADDRESS', nil).present?
  end

  # Everything still standing between this ticket and being closed. Empty means
  # it can be closed.
  def missing_close_requirements
    missing = []
    # Categoria and Catalogo de Servicos are different classifications; both are
    # required and neither substitutes the other.
    missing << MISSING_CATEGORY if ticket_category_id.blank?
    missing << MISSING_CATALOG unless classified?
    missing.concat(missing_communication_requirements)
    missing
  end

  def missing_communication_requirements
    return [] if closing_communication_sent?
    # Sem como enviar, a classificacao continua obrigatoria e a comunicacao nao:
    # o fechamento deixa de depender de algo que o ambiente nao permite fazer.
    return [] unless customer_email_deliverable?

    missing = [MISSING_COMMUNICATION]
    missing << MISSING_CONTACT_EMAIL if customer_email.blank?
    missing
  end

  def closeable?
    missing_close_requirements.empty?
  end

  # `skip_requirements` exists for administrative closes (grouping), never for
  # an agent closing an attendance.
  def ensure_closeable!(skip_requirements: false)
    return if skip_requirements

    missing = missing_close_requirements
    raise NotAllowed, missing if missing.any?
  end
end
