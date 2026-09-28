class TicketColumn < ApplicationRecord
  belongs_to :team

  has_many :tickets, -> { order(:position, :id) }, dependent: :restrict_with_error, inverse_of: :ticket_column
  # What the Kanban renders. Separate from `tickets` on purpose: positioning and
  # re-indexing must keep seeing every ticket in the column, otherwise a closed
  # ticket's slot would be handed out twice.
  # `triaged`: o chamado aberto pelo cliente so entra no quadro depois de alguem
  # aceita-lo na triagem. Ate la ele existe, aparece para o cliente e esta na
  # fila de triagem - mas nao entre os atendimentos em andamento da equipe.
  has_many :operational_tickets, -> { operational.triaged.order(:position, :id) },
           class_name: 'Ticket', inverse_of: :ticket_column, dependent: nil

  # `pending` and `completed` mark the mandatory "Pendente"/"Finalizado"
  # Estagios of a Mesa's Kanban: `pending` is where Projects::CreateTicketsService
  # lands new project tickets, `completed` is just the required "done" slot -
  # neither is hidden from the board because of its kind anymore. `hidden` (a
  # separate column) is what controls board visibility for ANY Estagio, kind
  # included (see TicketBoard.vue). `normal` is every other Estagio - a Mesa
  # can have as many of those as it wants, but at most one of each required
  # kind.
  #
  # `in_progress` is optional (a Mesa doesn't need one) and, unlike
  # pending/completed, never mandatory - it can be freely re-set back to
  # `normal` or deleted. It marks the Estagio that TicketStageOnAssignmentListener
  # moves a ticket into automatically once the Conversation linked to it gets
  # assigned to someone.
  KINDS = %w[normal pending completed in_progress].freeze
  REQUIRED_KINDS = %w[pending completed].freeze

  # Acoes que "Automacao de Estagio" (Configuracoes > Estagios) pode rodar
  # sozinha quando um ticket ENTRA nesta coluna - ver TicketColumnAutomationListener
  # (escuta o evento `ticket.moved`) e Tickets::ColumnAutomationService (executa
  # a lista). Cada item de `automation_actions` e um hash `{ "type" => ..., "value" => ... }`;
  # `value` fica de fora da validacao de formato aqui porque o que ele aceita
  # depende do `type` (ver Tickets::ColumnAutomationService).
  AUTOMATION_ACTION_TYPES = %w[set_priority set_status set_assignee clear_due_date clear_scheduled_at post_note].freeze

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  # O prazo do Estagio, em segundos. Nulo significa "esta coluna nao tem prazo" -
  # diferente de zero, que seria um prazo impossivel.
  validates :stage_threshold, numericality: { greater_than: 0 }, allow_nil: true
  validate :team_change_requires_empty_column, on: :update
  validate :kind_uniqueness_per_team, if: -> { kind != 'normal' }
  validate :automation_actions_format

  before_validation :set_default_position, on: :create
  before_save :reset_position_for_new_team, if: -> { persisted? && team_id_changed? }
  # Runs ahead of the callback `dependent: :restrict_with_error` installs, so the
  # API answers with a message that says how many tickets are in the way and what
  # to do about them instead of Rails' generic wording.
  before_destroy :ensure_no_tickets, prepend: true
  before_destroy :ensure_not_required_kind, prepend: true

  delegate :account, to: :team

  # Persists a new column order for a team's Kanban ("Mesa de Servico") from
  # an ordered array of column ids.
  def self.reorder!(team, column_ids)
    transaction do
      column_ids.each_with_index do |id, index|
        team.ticket_columns.where(id: id).update_all(position: index) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  def push_event_data
    {
      id: id,
      name: name,
      position: position,
      team_id: team_id,
      stage_threshold: stage_threshold,
      kind: kind,
      hidden: hidden,
      automation_actions: automation_actions,
      automations_enabled: automations_enabled,
      require_due_date: require_due_date,
      require_scheduled_at: require_scheduled_at,
      require_appointment: require_appointment,
      require_assignee: require_assignee
    }
  end

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (team&.ticket_columns&.maximum(:position) || -1) + 1
  end

  def ensure_no_tickets
    ticket_count = tickets.count
    return if ticket_count.zero?

    errors.add(:base, I18n.t('errors.ticket_column.has_tickets', count: ticket_count))
    throw :abort
  end

  # Pendente/Finalizado are mandatory Estagios of a Mesa's Kanban - deleting
  # either would silently break Projects::CreateTicketsService (no `pending`
  # target left) or leave tickets with no "done" slot to land in. `in_progress`
  # is not in this list on purpose - it's an optional marker, not a required slot.
  def ensure_not_required_kind
    return unless REQUIRED_KINDS.include?(kind)

    errors.add(:base, I18n.t("errors.ticket_column.required_kind.#{kind}"))
    throw :abort
  end

  # An Estagio can only be handed to another Mesa while it is empty: a ticket must
  # always sit in a column belonging to its own Mesa (Ticket#team_matches_ticket_column),
  # so moving a populated column would invalidate every ticket in it.
  def team_change_requires_empty_column
    return unless team_id_changed?

    ticket_count = tickets.count
    return if ticket_count.zero?

    errors.add(:base, I18n.t('errors.ticket_column.team_change_with_tickets', count: ticket_count))
  end

  def reset_position_for_new_team
    self.position = (TicketColumn.where(team_id: team_id).where.not(id: id).maximum(:position) || -1) + 1
  end

  # At most one Pendente and one Finalizado per Mesa - mirrors the DB's partial
  # unique index, but with a message the API can actually show.
  def kind_uniqueness_per_team
    return if team.blank?

    exists = TicketColumn.where(team_id: team_id, kind: kind).where.not(id: id).exists?
    return unless exists

    errors.add(:base, I18n.t("errors.ticket_column.kind_taken.#{kind}"))
  end

  # So o que impediria a automacao de rodar: uma acao de tipo desconhecido.
  # `value` nao e validado aqui de proposito - o significado dele muda por
  # `type`, e Tickets::ColumnAutomationService ja ignora silenciosamente um
  # valor vazio/invalido em vez de derrubar a execucao das outras acoes.
  def automation_actions_format
    return if automation_actions.blank?
    return errors.add(:automation_actions, 'must be a list of actions') unless automation_actions.is_a?(Array)

    unknown = automation_actions.filter_map { |action| action['type'] || action[:type] }.uniq - AUTOMATION_ACTION_TYPES
    return if unknown.empty?

    errors.add(:automation_actions, "unsupported action types: #{unknown.join(', ')}")
  end
end
