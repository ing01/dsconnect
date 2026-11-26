# Finaliza os tickets filhos de um pai ja fechado, com os dados dele: Resolucao,
# classificacao no Catalogo de Servicos e a mensagem ao cliente - o filho so' recebe o
# que ainda nao tem.
#
# A mensagem e' REGISTRADA no filho sem e-mail: o cliente ja a recebeu pelo pai.
#
# Cada filho continua passando pelas exigencias normais de fechamento. O que nao der
# para fechar (sem Categoria, checklist pendente...) fica como estava, sem copia
# nenhuma, e volta em `pending` com o que falta.
class Tickets::CloseChildrenService
  Result = Struct.new(:closed, :pending, keyword_init: true)

  # `allowed` decide, filho a filho, se quem esta fechando pode fecha-lo.
  def initialize(parent:, user:, allowed: ->(_child) { true })
    @parent = parent
    @user = user
    @allowed = allowed
  end

  def perform
    result = Result.new(closed: [], pending: [])

    @parent.children.where.not(status: [:closed, :cancelled]).order(:display_id).each do |child|
      missing = close(child)
      if missing.empty?
        result.closed << child
      else
        result.pending << { ticket: child, missing: missing }
      end
    end

    result
  end

  private

  # Devolve o que impediu o fechamento; vazio quando fechou. A transacao desfaz as
  # copias quando o filho acaba nao fechando.
  def close(child)
    return ['permission'] unless @allowed.call(child)

    Ticket.transaction(requires_new: true) do
      copy_classification(child)
      copy_communication(child)
      child.close!(@user, resolution: child.resolution.presence || @parent.resolution)
    end
    []
  rescue TicketClosing::NotAllowed => e
    e.missing
  rescue ActiveRecord::RecordInvalid => e
    child.checklist_pending? ? [TicketClosing::MISSING_CHECKLIST] : e.record.errors.full_messages
  end

  def copy_classification(child)
    return if child.classified? || !@parent.classified?

    child.classify!(@parent.service_catalog_item, @user)
  end

  # So' entre tickets da mesma Empresa: a mensagem aparece para o cliente do filho.
  def copy_communication(child)
    return if child.closing_communication_sent? || child.company_id != @parent.company_id

    original = @parent.ticket_customer_communications.outbound.registered.order(:closing, :created_at, :id).last
    return if original.blank?

    child.ticket_customer_communications.create!(
      user: @user, contact: original.contact, to_email: original.to_email,
      subject: child.display_subject, body: original.body,
      direction: 'outbound', closing: true, status: 'skipped', sent_at: Time.zone.now
    )
  end
end
