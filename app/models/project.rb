class Project < ApplicationRecord
  STAGES = %w[pendente onboarding requisito em_andamento acompanhamento pos finalizado].freeze

  belongs_to :account
  belongs_to :team
  belongs_to :company, optional: true
  belongs_to :contact, optional: true
  belongs_to :project_module, optional: true
  belongs_to :implementer, class_name: 'User', optional: true
  # Categoria sugerida para as Tarefas geradas deste Projeto (passo 2 do
  # cadastro) - so' um padrao pratico, nunca obrigatorio: o Modelo de Tarefa
  # (`ticket_category_name`) ainda tem prioridade quando casa com uma
  # Categoria da Mesa escolhida (ver `Projects::CreateTicketsService`).
  belongs_to :default_ticket_category, class_name: 'TicketCategory', optional: true

  has_many :tickets, dependent: :nullify

  validates :name, presence: true
  validates :stage, inclusion: { in: STAGES }

  enum status: { active: 0, completed: 1, cancelled: 2 }

  before_validation :sync_status_with_stage
  after_save :sync_system_started_on_to_company, if: :saved_change_to_system_started_on?
  # Only when finalizing (not on every save) - a project already sitting in
  # `finalizado` must stay editable (renaming it, fixing a date) even if a
  # ticket got reopened afterwards.
  validate :tickets_completed_before_finalizing, if: -> { stage_changed? && stage == 'finalizado' }

  scope :active_board, -> { where(status: :active).where.not(stage: 'finalizado') }
  scope :completed_board, -> { where(stage: 'finalizado').or(where(status: :completed)) }

  # An `open` ticket is the only status that still represents pending work -
  # resolved/closed/cancelled all count as "done" for this purpose (see
  # Ticket::STATUSES).
  def tickets_completed?
    !tickets.exists?(status: :open)
  end

  # Total de horas apontadas (TicketTimeEntry) em todos os tickets deste
  # projeto - "Apontamento Total".
  def total_hours
    TicketTimeEntry.joins(:ticket).where(tickets: { project_id: id }).sum(:hours)
  end

  # Called automatically when a ticket's `next_project_stage` fires
  # (Ticket#advance_project_stage_if_needed!). Deliberately silent instead of
  # raising when blocked: an agent resolving one ticket should never see the
  # completion of *their* ticket fail because a sibling ticket is still open -
  # the project just stays where it is until every ticket is done. Explicitly
  # setting stage to `finalizado` (drag-and-drop, editing the project) is a
  # different path and still goes through the validation above.
  def advance_stage!(new_stage)
    return unless STAGES.include?(new_stage.to_s)
    return if new_stage.to_s == 'finalizado' && !tickets_completed?

    update!(stage: new_stage.to_s)
  end

  # `cancelled` is not one of `STAGES` (it doesn't replace where the project sits
  # in the pipeline) - it's tracked entirely through `status` plus these two
  # columns, left independent of `sync_status_with_stage`. Guarded here instead
  # of as a validation: `sync_status_with_stage` runs in `before_validation` and
  # would silently flip `status` back to `completed` for a `finalizado` project
  # before any validation on `status` got a chance to see the attempted change.
  def cancel!(reason: nil)
    if stage == 'finalizado'
      errors.add(:status, I18n.t('errors.project.cannot_cancel_finalized'))
      raise ActiveRecord::RecordInvalid.new(self)
    end

    update!(status: :cancelled, cancelled_at: Time.current, cancellation_reason: reason)
  end

  def reactivate!
    update!(status: :active, cancelled_at: nil, cancellation_reason: nil)
  end

  private

  def tickets_completed_before_finalizing
    return if tickets_completed?

    errors.add(:stage, I18n.t('errors.project.tickets_pending'))
  end

  def sync_status_with_stage
    if stage == 'finalizado'
      self.status = :completed
    elsif completed? && stage != 'finalizado'
      self.status = :active
    end
  end

  # "Data de inicio do uso do sistema" na Empresa nao e' mais digitada a mao
  # quando ela tem Projeto - vem daqui. Uma Empresa pode ter mais de um
  # Projeto (um por modulo contratado); quando mais de um tem essa data
  # preenchida, vale a mais antiga (primeira vez que o cliente comecou a usar
  # qualquer parte do sistema) - decisao confirmada com a Ingrid.
  def sync_system_started_on_to_company
    return if company.blank?

    earliest = company.projects.where.not(system_started_on: nil).minimum(:system_started_on)
    company.update!(system_started_on: earliest)
  end
end
