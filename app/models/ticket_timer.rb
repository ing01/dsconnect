# == Schema Information
#
# Table name: ticket_timers
#
#  id                  :bigint           not null, primary key
#  accumulated_seconds :integer          default(0), not null
#  category            :string           default("implantacao"), not null
#  note                :text
#  started_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  ticket_id           :bigint           not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_ticket_timers_on_account_id         (account_id)
#  index_ticket_timers_on_ticket_id          (ticket_id)
#  index_ticket_timers_on_ticket_id_and_user_id  (ticket_id,user_id) UNIQUE
#  index_ticket_timers_on_user_id            (user_id)
#  index_ticket_timers_running_by_user       (user_id) WHERE (started_at IS NOT NULL)
#
# O cronometro de apontamento de um agente num ticket. Inicia, pausa, continua e,
# ao finalizar, vira um TicketTimeEntry (as horas lancadas) e some. Enquanto roda
# NAO conta em nenhum total ou relatorio: so o apontamento finalizado conta.
class TicketTimer < ApplicationRecord
  # As horas tem 4 casas (ver a migration das horas): o menor lancamento e' 0,0003 h (~1 s).
  MIN_HOURS = 0.0003
  HOURS_SCALE = 4

  belongs_to :account
  belongs_to :ticket
  belongs_to :user

  validates :category, inclusion: { in: TicketTimeEntry::CATEGORIES }
  validates :note, length: { maximum: ApplicationRecord::MAX_TEXT_COLUMN_LENGTH }
  validates :accumulated_seconds, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :user_id, uniqueness: { scope: :ticket_id }

  scope :running, -> { where.not(started_at: nil) }

  # Inicia um cronometro novo. Uma pessoa so trabalha numa coisa por vez: o que
  # estiver correndo (neste ou em outro ticket) e' pausado, sem perder o tempo.
  def self.start!(ticket:, user:, category: nil, note: nil)
    transaction do
      pause_running_of(user)
      create!(
        account_id: ticket.account_id, ticket: ticket, user: user,
        category: category.presence || 'implantacao', note: note.to_s.strip.presence,
        started_at: Time.current
      )
    end
  end

  def self.pause_running_of(user, except: nil)
    scope = running.where(user_id: user.id)
    scope = scope.where.not(id: except.id) if except
    scope.find_each(&:pause!)
  end

  def self.hours_from(seconds)
    [(seconds / 3600.0).round(HOURS_SCALE), MIN_HOURS].max
  end

  def running?
    started_at.present?
  end

  def status
    running? ? 'running' : 'paused'
  end

  def elapsed_seconds(now = Time.current)
    accumulated_seconds + (running? ? [(now - started_at).to_i, 0].max : 0)
  end

  def pause!
    return self unless running?

    update!(accumulated_seconds: elapsed_seconds, started_at: nil)
    self
  end

  def resume!
    return self if running?

    self.class.transaction do
      self.class.pause_running_of(user, except: self)
      update!(started_at: Time.current)
    end
    self
  end

  # Para o relogio, lanca as horas (TicketTimeEntry) e apaga o cronometro. O dia do
  # apontamento e' o em que o cronometro foi iniciado.
  def finish!
    self.class.transaction do
      entry = ticket.ticket_time_entries.create!(
        account_id: account_id, user: user, category: category, note: note,
        hours: self.class.hours_from(elapsed_seconds),
        worked_on: created_at.in_time_zone.to_date
      )
      destroy!
      entry
    end
  end
end
