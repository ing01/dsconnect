class CalendarEvent < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :recurrence_parent, class_name: 'CalendarEvent', optional: true

  has_many :calendar_event_attendees, dependent: :destroy
  has_many :attendees, through: :calendar_event_attendees, source: :user
  has_many :calendar_event_tickets, dependent: :destroy
  has_many :tickets, through: :calendar_event_tickets
  has_many :occurrence_exceptions, class_name: 'CalendarEventOccurrenceException', dependent: :destroy, inverse_of: :calendar_event
  # De proposito SEM um `has_one :owning_exception, dependent: :destroy` no
  # sentido contrario - combinado com o `belongs_to :replacement_event,
  # dependent: :destroy` do outro lado, os dois virariam uma cascata
  # circular (destruir o replacement destroi a excecao, que tenta destruir o
  # replacement de novo). Quem destroi um `replacement_event` direto e' so'
  # o proprio servico (`DestroyOccurrenceService`), que ja cuida de
  # desvincular a excecao ANTES de destrui-lo.

  # `single` (0, default) = evento comum, sem serie - cobre tanto um
  # CalendarEvent simples quanto o `replacement_event` de uma exceção. Não
  # se chama `none` porque colide com o método de classe
  # `ActiveRecord::Querying#none` (relação vazia).
  enum recurrence_frequency: { single: 0, daily: 1, weekly: 2, monthly: 3, yearly: 4 }

  validates :title, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  validate :end_at_after_start_at
  validate :recurrence_interval_present_when_recurring
  validate :recurrence_end_condition_mutually_exclusive

  before_validation :clear_recurrence_fields_when_not_recurring

  # `end_at` uses an inclusive convention (end of the last day for all-day/
  # multi-day events), so overlap is a plain closed-interval comparison.
  scope :overlapping, ->(from, to) { where('start_at <= ? AND end_at >= ?', to, from) }
  scope :series, -> { where.not(recurrence_frequency: :single) }

  def recurring?
    !single?
  end

  # Metodos finos para o jbuilder tratar uma linha comum e uma ocorrencia
  # virtual (`CalendarEvents::OccurrenceExpansionService::Occurrence`) da
  # MESMA forma, sem `if` na view.
  def is_recurring = recurring? # rubocop:disable Naming/PredicateName -- espelha o nome que o JSON expõe
  def recurring_series_id = recurring? ? id : nil
  def occurrence_date = nil

  private

  def end_at_after_start_at
    return if start_at.blank? || end_at.blank? || end_at >= start_at

    errors.add(:end_at, :invalid)
  end

  def clear_recurrence_fields_when_not_recurring
    return unless single?

    self.recurrence_interval = nil
    self.recurrence_end_at = nil
    self.recurrence_count = nil
  end

  def recurrence_interval_present_when_recurring
    return if single?

    if recurrence_interval.blank?
      errors.add(:recurrence_interval, :blank)
    elsif recurrence_interval < 1
      errors.add(:recurrence_interval, :greater_than, count: 0)
    end
  end

  def recurrence_end_condition_mutually_exclusive
    return if recurrence_end_at.blank? || recurrence_count.blank?

    errors.add(:recurrence_end_at, :taken)
  end
end
