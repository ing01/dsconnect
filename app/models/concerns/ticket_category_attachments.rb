# A exigencia de anexo que vem da Categoria.
#
# A regra e da Categoria, mas quem a carrega e o ticket: e ele que tem (ou nao)
# os arquivos. Fica num concern porque os dois caminhos de abertura - o do
# agente e o da Area do Cliente - precisam da mesma resposta.
module TicketCategoryAttachments
  extend ActiveSupport::Concern

  included do
    # Mudar a Categoria depois tambem passa por aqui: um ticket sem arquivo nao
    # pode ser reclassificado para uma Categoria que exige um.
    #
    # `on: :update` de proposito. Na CRIACAO o ticket precisa existir antes de o
    # anexo poder apontar para ele, entao ali a checagem e de quem recebe o
    # pedido - vide `Tickets::AttachmentRequirement`.
    validate :attachment_required_by_category, on: :update
  end

  def category_requires_attachment?
    ticket_category&.require_attachment?
  end

  def missing_required_attachment?
    category_requires_attachment? && ticket_attachments.empty?
  end

  private

  def attachment_required_by_category
    return unless will_save_change_to_attribute?(:ticket_category_id)
    return unless missing_required_attachment?

    errors.add(:ticket_category, I18n.t('tickets.attachments.required_by_category'))
  end
end
