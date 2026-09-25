# A triagem do chamado aberto pelo cliente.
#
# Quem abre pela Area do Cliente informa o PROBLEMA - categoria, assunto,
# descricao e arquivos. Para onde o chamado vai e decisao de quem atende, e essa
# decisao acontece aqui: o chamado fica parado na fila ate um agente aprova-lo e
# encaminha-lo a Mesa e ao Estagio certos.
module TicketTriage
  extend ActiveSupport::Concern

  included do
    belongs_to :triaged_by, class_name: 'User', optional: true

    # Avisa a operacao assim que o chamado entra na fila. No `after_create_commit`
    # porque a notificacao aponta para um ticket que precisa existir - e em
    # segundo plano porque quem abriu nao deve esperar a bandeja de todos os
    # agentes ser escrita.
    after_create_commit :notify_triage_queue, if: :pending_triage?

    scope :pending_triage, -> { where(pending_triage: true) }
    # O que ja pode andar no Kanban da equipe. O quadro usa este escopo: um
    # chamado em triagem ainda nao foi aceito por ninguem, e aparecer entre os
    # demais seria dar por iniciado um atendimento que nao comecou.
    scope :triaged, -> { where(pending_triage: false) }
  end

  # Aprova e encaminha, numa coisa so: aprovar sem dizer para onde deixaria o
  # chamado no limbo, e a Mesa de entrada foi escolhida pela Categoria, nao por
  # quem atende.
  def approve_triage!(user:, team:, column:, category: nil)
    raise ArgumentError, I18n.t('tickets.triage.not_pending') unless pending_triage?
    raise ArgumentError, I18n.t('tickets.triage.column_mismatch') if column.team_id != team.id

    transaction do
      assign_attributes(team: team, ticket_column: column, pending_triage: false,
                        triaged_at: Time.current, triaged_by: user)
      self.ticket_category = category if category
      save!
      log_triage_activity(user)
    end

    self
  end

  private

  def notify_triage_queue
    Tickets::TriageNotificationJob.perform_later(id)
  end

  def log_triage_activity(user)
    ticket_activities.create!(
      account_id: account_id, user: user, activity_type: :triaged,
      new_value: "#{team.name} / #{ticket_column.name}"
    )
  end
end
