class AddRecurrenceToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    # `none` (0, default) significa "evento simples, sem serie" - cobre tanto
    # um CalendarEvent comum quanto o `replacement_event` de uma exceção
    # (ver `calendar_event_occurrence_exceptions`).
    add_column :calendar_events, :recurrence_frequency, :integer, null: false, default: 0
    add_column :calendar_events, :recurrence_interval, :integer
    add_column :calendar_events, :recurrence_end_at, :datetime
    add_column :calendar_events, :recurrence_count, :integer

    # So para rastreabilidade de qual serie uma serie bifurcada ("editar esta
    # e as proximas" - ver UpdateOccurrenceService) veio; nenhuma leitura
    # depende disso.
    add_reference :calendar_events, :recurrence_parent, null: true,
                                                        foreign_key: { to_table: :calendar_events, on_delete: :nullify }
  end
end
