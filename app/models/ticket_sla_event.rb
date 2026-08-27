# O registro de auditoria dos relogios, espelhando SlaEvent das Conversations.
#
# Fica separado de TicketActivity de proposito: a atividade e a linha do tempo
# que o usuario le no ticket, esta tabela e a base dos relatorios de SLA (%
# dentro do prazo, tempo medio por estagio, vencidos por Mesa/atendente/
# prioridade) - que sairiam caros e fragis se tivessem de varrer atividades.
#
# Um evento por transicao, nunca um por varredura: a varredura so grava quando o
# estado muda de fato, entao um ticket parado nao gera linha nenhuma.
class TicketSlaEvent < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :ticket_applied_sla
  # Quem cumpriu o prazo, quando houve alguem. Nulo em vencimentos, que sao
  # detectados pela varredura, e nulo se o agente for removido depois.
  belongs_to :user, optional: true

  enum event_type: { started: 0, hit: 1, missed: 2, extended: 3 }

  # De onde veio o cumprimento do atendimento. Guardado em `meta[:source]`.
  SOURCE_TICKET_COMMUNICATION = 'ticket_communication'.freeze
  SOURCE_CONVERSATION_MESSAGE = 'conversation_message'.freeze

  before_validation :ensure_account_id, :ensure_ticket_id

  scope :for_kind, ->(kind) { joins(:ticket_applied_sla).where(ticket_applied_slas: { kind: kind }) }

  def push_event_data
    {
      id: id,
      event_type: event_type,
      sla_kind: ticket_applied_sla.kind,
      meta: meta,
      user: user ? { id: user.id, name: user.name } : nil,
      created_at: created_at.to_i
    }
  end

  private

  def ensure_account_id
    self.account_id ||= ticket_applied_sla&.account_id
  end

  def ensure_ticket_id
    self.ticket_id ||= ticket_applied_sla&.ticket_id
  end
end
