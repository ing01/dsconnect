# Soma, numa passada so', os 8 indicadores do resumo do "Chat detalhado".
class ChatDetailReport::SummaryAccumulator
  # Horas sem limite de 24: "3173:10:09".
  def self.hms(seconds)
    seconds = seconds.to_i
    format('%<h>02d:%<m>02d:%<s>02d', h: seconds / 3600, m: (seconds % 3600) / 60, s: seconds % 60)
  end

  def initialize
    @attended = 0
    @cancelled = 0
    @first_contact = 0
    @durations = []
    @waits = []
    @contacts = Set.new
    @tickets = Set.new
  end

  def add(entry)
    @tickets.merge(entry.ticket_ids)
    if entry.attended
      add_attended(entry)
    elsif entry.finished
      add_cancelled
    end
  end

  def to_h
    {
      attended: @attended, linked_tickets: @tickets.size, first_contact: @first_contact,
      average_duration: self.class.hms(average(@durations)), contacts: @contacts.size,
      average_wait: self.class.hms(average(@waits)), total_time: self.class.hms(@durations.sum), cancelled: @cancelled
    }
  end

  private

  # Finalizado sem ninguem ter assumido; aberto e sem atendente ainda nao e' cancelado.
  def add_cancelled
    @cancelled += 1
  end

  def add_attended(entry)
    @attended += 1
    @first_contact += 1 if entry.first_contact
    @contacts << entry.contact_id
    @waits << entry.wait
    @durations << entry.duration if entry.finished
  end

  def average(values)
    values.empty? ? 0 : values.sum / values.size
  end
end
