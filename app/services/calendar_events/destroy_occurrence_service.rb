# Aplica uma exclusao a UMA ocorrencia de uma serie recorrente, no escopo
# escolhido pela pessoa - ver CalendarEvents::UpdateOccurrenceService para o
# comentario simetrico do lado da edicao.
class CalendarEvents::DestroyOccurrenceService
  pattr_initialize [:calendar_event!, :scope!, :occurrence_date]

  def perform
    case scope.to_s
    when 'occurrence' then cancel_single_occurrence
    when 'future'     then truncate_and_destroy_future
    when 'series'     then calendar_event.destroy! # cascata: occurrence_exceptions -> replacement_event
    else raise ArgumentError, "unknown scope #{scope}"
    end
  end

  private

  attr_reader :calendar_event, :occurrence_date

  # Cria/atualiza uma excecao CANCELLED para esta data (sem
  # replacement_event). Se ja havia uma excecao MODIFIED aqui, destroi o
  # replacement_event antigo antes de trocar o tipo - ela nao pode carregar
  # os dois ao mesmo tempo.
  def cancel_single_occurrence
    ActiveRecord::Base.transaction(requires_new: true) do
      exception = calendar_event.occurrence_exceptions.find_or_initialize_by(occurrence_date: occurrence_date)
      exception.account = calendar_event.account
      evento_antigo = exception.replacement_event

      # Desvincula e salva ANTES de destruir o antigo - destruir primeiro
      # acionaria o `dependent: :destroy` do `belongs_to` para tentar
      # destruir de novo um registro que esta' sendo apagado por baixo dele.
      exception.replacement_event = nil
      exception.kind = :cancelled
      exception.save!
      evento_antigo&.destroy!
    end
  end

  # A serie continua existindo com as ocorrencias PASSADAS intactas; so'
  # passa a terminar um dia antes desta data. Excecoes nesta data ou depois
  # dela deixam de ter sentido (a serie nem chega mais la') - sao destruidas
  # junto com qualquer replacement_event que carreguem.
  def truncate_and_destroy_future
    ActiveRecord::Base.transaction(requires_new: true) do
      calendar_event.occurrence_exceptions.where('occurrence_date >= ?', occurrence_date).destroy_all
      calendar_event.update!(recurrence_end_at: occurrence_date - 1.day, recurrence_count: nil)
    end
  end
end
