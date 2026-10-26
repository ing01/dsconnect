# O Sprint do Modulo de Desenvolvimento - uma Mesa com o modulo ativado
# (`Team#development_module_enabled`) organiza seus tickets em Sprints
# semanais. `sprint_id: nil` num ticket significa Backlog (sem sprint).
class Sprint < ApplicationRecord
  belongs_to :account
  belongs_to :team
  has_many :tickets, dependent: :nullify

  enum status: { upcoming: 0, active: 1, completed: 2 }

  validates :name, presence: true
  validates :starts_on, :ends_on, presence: true
  validate :ends_on_after_starts_on

  scope :ordered, -> { order(:starts_on) }

  # So' um Sprint ativo por Mesa de cada vez - o anterior (se houver) volta a
  # "upcoming", nao "completed": ativar nao e' o mesmo que concluir, e' so'
  # trocar qual Sprint a tela de Sprint ativo abre por padrao.
  def activate!
    return if active?

    if completed?
      errors.add(:status, :invalid)
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      team.sprints.active.where.not(id: id).update_all(status: Sprint.statuses[:upcoming]) # rubocop:disable Rails/SkipsModelValidations
      update!(status: :active)
    end
  end

  # Fecha o Sprint e reencaminha pro PROXIMO Sprint (pela data) os tickets que
  # ainda nao chegaram no Estagio final da Mesa (`TicketColumn#kind ==
  # "completed"`) - o que ja chegou la' fica registrado neste Sprint, como
  # historico do que foi entregue nele. Sem proximo Sprint, esses tickets
  # voltam pro Backlog (`sprint_id: nil`).
  def conclude!
    return if completed?

    next_sprint = team.sprints.where('starts_on > ?', starts_on).where.not(status: :completed).ordered.first
    transaction do
      tickets.joins(:ticket_column).where.not(ticket_columns: { kind: 'completed' })
             .update_all(sprint_id: next_sprint&.id) # rubocop:disable Rails/SkipsModelValidations
      update!(status: :completed)
      next_sprint&.activate!
    end
  end

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, :invalid)
  end
end
