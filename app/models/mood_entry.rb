class MoodEntry < ApplicationRecord
  belongs_to :account
  belongs_to :user

  enum mood: { great: 0, good: 1, neutral: 2, low: 3, bad: 4 }

  validates :entry_date, presence: true
  validates :user_id, uniqueness: { scope: [:account_id, :entry_date] }
end
