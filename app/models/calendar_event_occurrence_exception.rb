# Uma ocorrencia de uma serie recorrente que foi cancelada ou editada
# individualmente (ver CalendarEvent#recurring? e
# CalendarEvents::OccurrenceExpansionService). Nao tem sentido sem a serie -
# por isso o FK para `calendar_event` e' CASCADE (ao contrario do `nullify`
# usado em Company/Contact noutras features, onde o FILHO sobrevive ao pai -
# aqui a excecao E' dado da serie).
class CalendarEventOccurrenceException < ApplicationRecord
  belongs_to :account
  belongs_to :calendar_event, inverse_of: :occurrence_exceptions
  belongs_to :replacement_event, class_name: 'CalendarEvent', optional: true, dependent: :destroy

  enum kind: { cancelled: 0, modified: 1 }

  validates :occurrence_date, presence: true
  validates :occurrence_date, uniqueness: { scope: :calendar_event_id }
  validate :replacement_event_present_only_when_modified

  private

  def replacement_event_present_only_when_modified
    if modified? && replacement_event_id.blank?
      errors.add(:replacement_event, :blank)
    elsif cancelled? && replacement_event_id.present?
      errors.add(:replacement_event, :present)
    end
  end
end
