# Aplica uma edicao a UMA ocorrencia de uma serie recorrente, no escopo
# escolhido pela pessoa (ver CalendarEventFormDialog/RecurrenceScopeDialog no
# frontend e o comentario no controller).
class CalendarEvents::UpdateOccurrenceService
  pattr_initialize [:calendar_event!, :scope!, :attributes!, :occurrence_date]

  def perform
    case scope.to_s
    when 'occurrence' then update_single_occurrence
    when 'future'     then fork_series_from_occurrence
    when 'series'     then update_whole_series
    else raise ArgumentError, "unknown scope #{scope}"
    end
  end

  private

  attr_reader :calendar_event, :attributes

  # So' esta data: cria/atualiza UMA excecao `modified`, com um
  # `replacement_event` proprio carregando os campos editados. A serie e a
  # regra de recorrencia continuam intocadas.
  def update_single_occurrence
    ActiveRecord::Base.transaction(requires_new: true) do
      exception = calendar_event.occurrence_exceptions.find_or_initialize_by(occurrence_date: occurrence_date)
      exception.account = calendar_event.account

      replacement = exception.replacement_event || calendar_event.account.calendar_events.new(
        team_id: calendar_event.team_id, created_by: calendar_event.created_by, recurrence_frequency: :single
      )
      replacement.assign_attributes(occurrence_base_attributes.merge(editable_attributes))
      replacement.save!

      exception.kind = :modified
      exception.replacement_event = replacement
      exception.save!

      replacement
    end
  end

  # Divide a serie: a serie ANTIGA passa a terminar um dia antes desta
  # ocorrencia; nasce uma serie NOVA a partir dela, com os campos editados,
  # mesma frequencia/intervalo. Excecoes da serie antiga ESTRITAMENTE depois
  # desta data continuam valendo - sao reparentadas para a serie nova. Uma
  # excecao EXATAMENTE nesta data e' destruida: a propria serie nova ja
  # representa essa data nativamente pelo seu `start_at`, nao precisa de
  # excecao para isso.
  def fork_series_from_occurrence
    ActiveRecord::Base.transaction(requires_new: true) do
      destroy_exception_at_occurrence_date!
      truncate_original_series!

      new_series = calendar_event.account.calendar_events.new(
        team_id: calendar_event.team_id,
        created_by: calendar_event.created_by,
        recurrence_frequency: calendar_event.recurrence_frequency,
        recurrence_interval: calendar_event.recurrence_interval,
        recurrence_parent: calendar_event
      )
      new_series.assign_attributes(occurrence_base_attributes.merge(editable_attributes))
      new_series.save!

      reparent_future_exceptions!(new_series)
      new_series
    end
  end

  # Atualiza a linha mestre diretamente - inclusive a propria regra de
  # recorrencia, se o formulario mudou frequencia/intervalo/termino. Excecoes
  # existentes continuam valendo por cima.
  def update_whole_series
    calendar_event.update!(attributes)
    calendar_event
  end

  def destroy_exception_at_occurrence_date!
    calendar_event.occurrence_exceptions.where(occurrence_date: occurrence_date).destroy_all
  end

  def truncate_original_series!
    calendar_event.update!(recurrence_end_at: occurrence_date - 1.day, recurrence_count: nil)
  end

  def reparent_future_exceptions!(new_series)
    calendar_event.occurrence_exceptions.where('occurrence_date > ?', occurrence_date)
                  .update_all(calendar_event_id: new_series.id) # rubocop:disable Rails/SkipsModelValidations -- so troca o FK, nada a validar de novo
  end

  # Titulo/descricao/horario etc. do evento original, na data desta
  # ocorrencia - usado como base antes de aplicar o que a pessoa editou
  # (`editable_attributes`), para que campos nao tocados no formulario
  # continuem iguais aos da serie.
  def occurrence_base_attributes
    {
      title: calendar_event.title, description: calendar_event.description, all_day: calendar_event.all_day,
      location: calendar_event.location, color: calendar_event.color,
      start_at: shift_to(calendar_event.start_at, occurrence_date), end_at: shift_to(calendar_event.end_at, occurrence_date)
    }
  end

  # So' os campos que o formulario de evento realmente edita - nunca a
  # regra de recorrencia em si, que nao faz sentido numa ocorrencia unica
  # (`occurrence`) nem precisa ser reenviada na bifurcacao (`future`, que ja
  # a copia explicitamente da serie antiga).
  def editable_attributes
    attributes.except(:recurrence_frequency, :recurrence_interval, :recurrence_end_at, :recurrence_count, :team_id)
  end

  def shift_to(datetime, date)
    datetime.change(year: date.year, month: date.month, day: date.day)
  end
end
