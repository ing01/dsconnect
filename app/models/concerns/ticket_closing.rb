# What a ticket needs before an agent may close it: a service catalogue
# classification, a closing message that actually reached the customer, and the
# Resolucao - o que foi feito para resolver, que alimenta o DueRules e a
# documentacao.
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
  MISSING_CHECKLIST = 'checklist'.freeze
  MISSING_RESOLUTION = 'resolution'.freeze

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
      attach_catalog_item_forms!(item)
    end
  end

  # Os Formularios vinculados ao item do Catalogo entram automaticamente no
  # checklist do ticket, igual um Checklist anexado (mesma logica de posicao
  # continua) - sem duplicar quando o ticket ja tem aquele Formulario.
  def attach_catalog_item_forms!(item)
    return if item.blank?

    already_attached = ticket_checklist_items.where.not(form_id: nil).pluck(:form_id)
    pending_forms = item.forms.where.not(id: already_attached)
    return if pending_forms.none?

    base_position = ticket_checklist_items.maximum(:position) || -1
    pending_forms.each_with_index do |form, index|
      ticket_checklist_items.create!(
        account_id: account_id, title: form.name, item_type: 'form', form: form,
        position: base_position + index + 1
      )
    end
  end

  def classified?
    service_catalog_item_id.present?
  end

  # Vale a comunicacao que CHEGOU ao cliente - por e-mail, ou registrada sem
  # e-mail quando a equipe ja falou com ele por outro meio. Nos dois casos o
  # texto esta no chamado e visivel na Area do Cliente; o que nao vale e a
  # tentativa que falhou.
  #
  # Conta qualquer mensagem da equipe ao cliente neste ticket, nao so a enviada
  # pela etapa de encerramento: quem ja falou com ele direto no ticket nao e
  # obrigado a repetir a comunicacao ao fechar. Resposta do CLIENTE (inbound)
  # nao conta, porque nao e a equipe falando.
  def closing_communication_sent?
    ticket_customer_communications.outbound.registered.exists?
  end

  # The address the closing message would go to. Nil NAO bloqueia o fechamento:
  # sem e-mail nao ha para quem escrever, entao a comunicacao de encerramento
  # simplesmente nao e exigida (ver `missing_communication_requirements`).
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
    missing << MISSING_RESOLUTION if resolution.blank?
    missing.concat(missing_communication_requirements)
    # Same rule as `ensure_checklist_completed!`: a linked Apontamento
    # (calendar_event) bypasses pending checklist items.
    missing << MISSING_CHECKLIST if checklist_pending?
    missing
  end

  def missing_communication_requirements
    return [] if closing_communication_sent?
    # Ticket filho de uma Mesa de Desenvolvimento: quem fala com o cliente e' o
    # ticket PAI (o atendimento). O dev encerra o filho sem comunicacao propria.
    return [] if development_child?
    # Solicitante sem e-mail: nao ha a quem avisar, e o ticket fecha normalmente.
    # O maximo que acontece e nao sair e-mail nenhum.
    return [] if customer_email.blank?
    # Sem como enviar, a classificacao continua obrigatoria e a comunicacao nao:
    # o fechamento deixa de depender de algo que o ambiente nao permite fazer.
    return [] unless customer_email_deliverable?

    [MISSING_COMMUNICATION]
  end

  def development_child?
    parent_id.present? && team&.development_module_enabled?
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
