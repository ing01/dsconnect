# Who the ticket is for: the Empresa (Company) and the Solicitante (Contact).
#
# Two separate concepts - the organization and the person who asked - that a
# ticket can carry both of, either of, or neither. What ties them together is
# that they must not disagree.
module TicketCustomer
  extend ActiveSupport::Concern

  included do
    belongs_to :company, optional: true
    # Optional because a ticket can be opened before the requester is identified.
    belongs_to :contact, optional: true

    validate :company_belongs_to_account
    validate :contact_belongs_to_account
    validate :contact_belongs_to_company
  end

  # Prefers the ticket's own `contact`. Falls back to the earliest linked
  # Conversation's contact for tickets created before the FK existed, and for
  # tickets opened from a chat where nobody set it explicitly. Resolved in Ruby
  # so it reuses the `conversations: :contact` preload instead of firing a
  # query, and `min_by(&:id)` makes the fallback deterministic - `.first` has no
  # ORDER BY.
  def requester_contact
    return @requester_contact if defined?(@requester_contact)

    @requester_contact = contact || earliest_conversation&.contact
  end

  # A conversa mais antiga, sem encher a associacao.
  #
  # `conversations.to_a` aproveita o preload do Kanban, mas quando nao ha
  # preload ele CARREGA a associacao e a congela: perguntar quem e o
  # solicitante antes de vincular a conversa deixava `ticket.conversations`
  # vazio pelo resto da vida daquela instancia. Por isso o `to_a` so entra
  # quando alguem ja carregou de fato.
  def earliest_conversation
    return conversations.to_a.min_by(&:id) if conversations.loaded?

    conversations.order(:id).first
  end

  # "#26 - [ELETROSUL - FILIAL] | [João Vitor] | [Erro na emissão da nota]",
  # skipping whichever parts this ticket does not have rather than rendering
  # empty brackets. Same shape the detail page header shows.
  def display_subject
    parts = [company&.name, requester_contact&.name, title].compact_blank
    "##{display_id} - #{parts.map { |part| "[#{part}]" }.join(' | ')}"
  end

  private

  def company_belongs_to_account
    return if company.blank?

    errors.add(:company, :invalid) if company.account_id != account_id
  end

  def contact_belongs_to_account
    return if contact.blank?

    errors.add(:contact, :invalid) if contact.account_id != account_id
  end

  # The Solicitante is a person AT the Empresa, so the two cannot disagree. Only
  # checked when the ticket has an Empresa: a ticket opened from a chat by
  # somebody with no company still has a requester.
  def contact_belongs_to_company
    return if contact.blank? || company_id.blank?

    errors.add(:contact, :invalid) if contact.company_id != company_id
  end
end
