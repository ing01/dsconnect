# What a ticket needs in order to be opened, and what the Mesa owns.
#
# All of these are `on: :create`. Enforcing them on every save would make
# tickets opened before these rules existed impossible to edit - including
# simply dragging one across the Kanban - and `assign_to_me` deliberately lets
# an administrator take a ticket in a Mesa they are not a member of, which
# TicketPolicy allows.
module TicketOpening
  extend ActiveSupport::Concern

  included do
    # The Mesa's category for this ticket. Optional at the association level and
    # required on create below, for the same reason.
    belongs_to :ticket_category, optional: true

    validates :description, presence: true, on: :create
    validates :priority, presence: true, on: :create
    validates :ticket_category, presence: true, on: :create

    validate :ticket_category_belongs_to_team
    validate :ticket_complexity_available_for_team
    validate :assignee_belongs_to_team, on: :create

    # Categories belong to a Mesa, so one that moved to another Mesa no longer
    # has a valid category. Dropping it is the same rule the creation form
    # follows when the Mesa changes - keeping it would make every cross-Mesa
    # move invalid.
    before_validation :clear_incompatible_category, if: :team_id_changed?
    # A Complexidade e da conta, mas quais Mesas a oferecem e configuravel: um
    # nivel que a Mesa nova nao atende e limpado pelo mesmo motivo da Categoria -
    # manter faria toda troca de Mesa ser recusada. Quem fica sem Complexidade
    # precisa escolher outra antes de fechar (ver TicketClosing).
    #
    # `persisted?` importa: na CRIACAO `team_id_changed?` tambem e verdadeiro (nil
    # -> valor), e limpar ali faria a escolha do formulario ser descartada em
    # silencio. Ao abrir, um nivel que a Mesa nao oferece e recusado.
    before_validation :clear_unavailable_complexity, if: -> { persisted? && team_id_changed? }
  end

  private

  def clear_incompatible_category
    return if ticket_category_id.blank?
    return if ticket_category&.team_id == team_id

    self.ticket_category_id = nil
  end

  def clear_unavailable_complexity
    return if ticket_complexity_id.blank?
    return if ticket_complexity&.available_for_team?(team_id)

    self.ticket_complexity_id = nil
  end

  def ticket_category_belongs_to_team
    return if ticket_category.blank? || team_id.blank?

    errors.add(:ticket_category, :invalid) if ticket_category.team_id != team_id
  end

  # A Complexidade escolhida precisa ser uma que a Mesa oferece, e isso vale no
  # servidor: a tela filtrar a lista e conveniencia.
  #
  # So o que MUDOU e validado. Um ticket antigo, gravado quando a matriz era
  # outra, nao pode ficar impossivel de salvar por causa de um campo que ninguem
  # tocou - o mesmo cuidado que o comentario no topo deste arquivo descreve.
  def ticket_complexity_available_for_team
    return if ticket_complexity.blank? || team_id.blank?
    return unless will_save_change_to_ticket_complexity_id?
    return if ticket_complexity.available_for_team?(team_id)

    errors.add(:ticket_complexity, :invalid)
  end

  def assignee_belongs_to_team
    return if assignee_id.blank? || team.blank?

    errors.add(:assignee, :invalid) unless team.members.exists?(id: assignee_id)
  end
end
