# Um periodo de atendimento dentro de um dia da semana (0=domingo..6=sabado).
# Guardado em minutos desde a meia-noite pra comparar direto com a hora atual,
# sem parsear string toda vez.
#
# Propositalmente sem indice unico por dia: uma conta pode ter mais de um
# periodo no mesmo dia (ex: expediente normal de manha/tarde + plantao a
# noite no fim de semana) - ver AttendanceWindow.covers?.
class AttendanceWindow < ApplicationRecord
  belongs_to :account

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_minute, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 1440 }
  validates :end_minute, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1440 }
  validate :end_after_start

  scope :for_day, ->(day) { where(day_of_week: day) }

  # `minute_of_day` e o minuto local (0..1439) do momento que se quer checar -
  # quem chama ja resolveu o fuso horario da conta antes de chegar aqui.
  def self.covers?(day_of_week:, minute_of_day:)
    for_day(day_of_week).where('start_minute <= ? AND end_minute > ?', minute_of_day, minute_of_day).exists?
  end

  private

  def end_after_start
    return if start_minute.blank? || end_minute.blank?

    errors.add(:end_minute, 'must be after start_minute') if end_minute <= start_minute
  end
end
