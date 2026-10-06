class CreateCalendarEventOccurrenceExceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_event_occurrence_exceptions do |t|
      # A exceção NÃO tem sentido sem a série - ao contrário do `nullify`
      # usado em Company/Contact noutras features (onde o FILHO é o dado
      # histórico que sobrevive ao pai), aqui a exceção É dado da série:
      # destruir a série tem que destruir suas exceções com ela.
      t.references :calendar_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: true

      # A data (no fuso da serie) da ocorrencia original sendo sobrescrita.
      t.date :occurrence_date, null: false

      # 0 = cancelled (ocorrencia escondida, sem substituto), 1 = modified
      # (ocorrencia escondida, `replacement_event` carrega os campos editados).
      t.integer :kind, null: false, default: 0

      # Presente so quando `modified` - um CalendarEvent comum
      # (recurrence_frequency: none), reaproveitando todo o model/validacoes/
      # attendees/tickets ja existentes em vez de duplicar schema.
      t.references :replacement_event, null: true,
                                       foreign_key: { to_table: :calendar_events, on_delete: :cascade }

      t.timestamps
    end

    # Trava no BANCO, nao so na validacao - mesmo padrao de
    # uniq_calendar_event_attendee/index_monthly_surveys_unique_per_contact_month.
    add_index :calendar_event_occurrence_exceptions, [:calendar_event_id, :occurrence_date],
              unique: true, name: 'uniq_calendar_event_occurrence_exception'
  end
end
