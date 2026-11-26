# A acao "Alterar campo" da Automacao de Estagio: `{ "field" => ..., "value" => ... }`.
#
# Valor em branco LIMPA o campo (no Sprint, e' voltar para o Backlog). Um valor que
# nao serve para a Mesa do ticket - Sprint de outra Mesa, pessoa de fora... - nao
# muda nada, em vez de limpar o campo sem querer.
class Tickets::AutomationFieldChange
  # Campo => como achar, para este ticket, o valor configurado. Datas so' podem ser
  # limpas: uma data fixa na configuracao do Estagio ficaria vencida.
  FIELDS = {
    'sprint' => [:sprint_id, ->(ticket, value) { ticket.team.sprints.find_by(id: value)&.id }],
    'priority' => [:priority, ->(_ticket, value) { Ticket.priorities.key?(value) ? value : nil }],
    'assignee' => [:assignee_id, ->(ticket, value) { ticket.team.members.find_by(id: value)&.id }],
    'category' => [:ticket_category_id, ->(ticket, value) { ticket.team.ticket_categories.find_by(id: value)&.id }],
    'complexity' => [:ticket_complexity_id,
                     ->(ticket, value) { ticket.account.ticket_complexities.available_for_team(ticket.team_id).find_by(id: value)&.id }],
    'development_type' => [:development_type, ->(_ticket, value) { Ticket.development_types.key?(value) ? value : nil }],
    'due_date' => [:due_date, ->(_ticket, _value) {}],
    'scheduled_at' => [:scheduled_at, ->(_ticket, _value) {}]
  }.freeze

  pattr_initialize [:ticket!, :field!, :value!]

  def perform
    attribute, resolver = FIELDS[field.to_s]
    return if attribute.blank?
    return ticket.update!(attribute => nil) if value.blank?

    resolved = resolver.call(ticket, value.to_s)
    ticket.update!(attribute => resolved) unless resolved.nil?
  end
end
