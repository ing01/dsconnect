class CalendarEvent < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :calendar_event_attendees, dependent: :destroy
  has_many :attendees, through: :calendar_event_attendees, source: :user
  has_many :calendar_event_tickets, dependent: :destroy
  has_many :tickets, through: :calendar_event_tickets

  validates :title, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  validate :end_at_after_start_at

  # `end_at` uses an inclusive convention (end of the last day for all-day/
  # multi-day events), so overlap is a plain closed-interval comparison.
  scope :overlapping, ->(from, to) { where('start_at <= ? AND end_at >= ?', to, from) }

  private

  def end_at_after_start_at
    return if start_at.blank? || end_at.blank? || end_at >= start_at

    errors.add(:end_at, :invalid)
  end
end
