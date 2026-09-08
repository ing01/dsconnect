# O lado Ticket dos tres SLAs: atendimento, estagio e solucao.
#
# O ticket nao calcula nada - ele apenas avisa o Tickets::Sla::ManagerService do
# que aconteceu com ele. Toda a regra vive la, e o vencimento e sempre decidido
# no backend.
#
# Ate esta versao o ticket tinha um unico `due_at`, que nao conseguia
# representar tres relogios com estado independente. Aquele prazo virou o
# relogio de solucao (vide MigrateTicketDueAtToResolutionSla).
module TicketSlaExtendable
  extend ActiveSupport::Concern

  included do
    has_many :ticket_applied_slas, dependent: :destroy
    has_many :ticket_sla_events, dependent: :destroy
    has_many :ticket_sla_extensions, dependent: :destroy

    after_create_commit :start_sla_clocks
    after_update_commit :sync_sla_clocks
  end

  # A linha da matriz Mesa x Prioridade que vale para este ticket. Nula quando a
  # Mesa nao configurou prazo para a prioridade - e um ticket sem promessa de
  # prazo, nao um ticket com prazo zero.
  def ticket_sla_policy
    return if team_id.blank? || priority.blank?

    TicketSlaPolicy.find_by(team_id: team_id, priority: Ticket.priorities[priority])
  end

  # Os tres relogios vigentes, para a tela e para os serializers.
  #
  # Resolvido em Ruby sobre a colecao ja carregada (vide DETAIL_INCLUDES) em vez
  # de tres consultas por ticket: o ativo de cada tipo, ou o ultimo encerrado
  # quando nao ha nenhum correndo - um ticket fechado ainda mostra o resultado.
  def current_slas
    ticket_applied_slas.to_a
                       .group_by(&:kind)
                       .values
                       .map { |clocks| clocks.min_by { |clock| [clock.active? ? 0 : 1, -clock.started_at.to_i] } }
                       .sort_by { |clock| TicketAppliedSla.kinds[clock.kind] }
  end

  def current_sla(kind)
    sla_manager_clocks.current(kind)
  end

  # Ajusta um prazo especifico, por horas ou por data e hora. Qual dos tres e
  # escolha de quem chama - um ajuste nunca vale para os tres de uma vez.
  def adjust_sla!(kind:, reason:, hours: nil, due_at: nil, user: Current.user)
    sla_manager_clocks.adjust_deadline(kind, hours: hours, due_at: due_at, reason: reason, user: user)
  end

  # Publico porque o ClockService registra a atividade por aqui, mantendo o
  # historico do ticket como unica linha do tempo que o usuario le.
  def log_sla_extension_activity(extension, user, mode = 'hours')
    ticket_activities.create!(
      account_id: account_id, user: user, activity_type: :sla_hours_added,
      previous_value: extension.previous_due_at&.iso8601, new_value: extension.new_due_at&.iso8601,
      meta: {
        hours: extension.hours.to_f, reason: extension.reason, sla_kind: extension.sla_kind,
        # Como o prazo foi mexido. Nao da para deduzir do sinal das horas: uma
        # data escolhida la na frente tambem rende horas positivas.
        mode: mode
      }
    )
  end

  private

  def sla_manager
    @sla_manager ||= Tickets::Sla::ManagerService.new(ticket: self)
  end

  def sla_manager_clocks
    @sla_manager_clocks ||= Tickets::Sla::ClockService.new(ticket: self)
  end

  def start_sla_clocks
    sla_manager.ticket_opened
  end

  # Uma unica passagem por mudanca: as quatro transicoes que mexem em relogio sao
  # mutuamente exclusivas o bastante para nao competirem entre si.
  def sync_sla_clocks
    return sla_manager.ticket_terminated if terminated_by_this_change?
    return sla_manager.ticket_reopened if reopened_by_this_change?

    sla_manager.stage_changed if saved_change_to_ticket_column_id?
    sla_manager.priority_changed if saved_change_to_priority?
  end

  def terminated_by_this_change?
    saved_change_to_status? && !open?
  end

  def reopened_by_this_change?
    saved_change_to_status? && open?
  end
end
