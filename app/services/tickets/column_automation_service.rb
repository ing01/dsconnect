# Roda a "Automacao de Estagio" (TicketColumn#automation_actions) de um
# ticket que acabou de ENTRAR na coluna - configurado em Configuracoes >
# Estagios ("quando cair em Finalizado, muda a prioridade, fecha o ticket...").
#
# Cada acao roda isolada: uma falha (ex: o ticket nao pode ser fechado por
# falta de categoria/comunicacao) fica registrada no rastreador de excecoes e
# NAO impede as demais acoes de rodar - uma automacao mal configurada nunca
# pode travar o resto da lista.
class Tickets::ColumnAutomationService
  pattr_initialize [:ticket!, :ticket_column!]

  def perform
    ticket_column.automation_actions.each do |action|
      run_action(action.with_indifferent_access)
    end
  end

  private

  def run_action(action)
    case action[:type]
    when 'set_priority' then set_priority(action[:value])
    when 'set_status' then set_status(action[:value])
    when 'set_assignee' then set_assignee(action[:value])
    when 'clear_due_date' then ticket.update!(due_date: nil)
    when 'clear_scheduled_at' then ticket.update!(scheduled_at: nil)
    when 'post_note' then post_note(action[:value])
    when 'move_parent_to_column' then move_parent_to_column(action[:value])
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: ticket.account).capture_exception
  end

  def set_priority(value)
    return unless Ticket.priorities.key?(value.to_s)

    ticket.update!(priority: value)
  end

  # Sempre `nil` como usuario: quem fez a mudanca foi a automacao do Estagio,
  # nao uma pessoa - o mesmo `Current.user` nulo que qualquer job de fundo ja
  # tem fora de uma requisicao.
  def set_status(value)
    case value.to_s
    when 'resolved' then ticket.resolve!(nil)
    # `skip_requirements`: e a mesma logica administrativa de Tickets::MergeService -
    # a automacao decidiu fechar o ticket, e nao pode ficar travada esperando
    # categoria/comunicacao que ninguem vai preencher para um fechamento automatico.
    when 'closed' then ticket.close!(nil, skip_requirements: true)
    when 'cancelled' then ticket.cancel!(nil)
    when 'open' then ticket.reopen!(nil)
    end
  end

  def set_assignee(value)
    agent_id = value.presence
    return if agent_id.present? && !ticket.team.members.exists?(id: agent_id)

    ticket.update!(assignee_id: agent_id)
  end

  def post_note(text)
    return if text.blank?

    ticket.ticket_activities.create!(
      account_id: ticket.account_id, user: nil, activity_type: :automation_note, new_value: text
    )
  end

  # Move o ticket PAI (se tiver) para um Estagio especifico, de qualquer Mesa -
  # `Ticket#move_to!` ja ajusta o `team_id` sozinho quando o Estagio alvo e' de
  # outra Mesa. Silencioso de proposito quando nao ha pai ou a coluna configurada
  # nao existe mais (conta deletou o Estagio depois de configurar a automacao) -
  # nao e' erro do usuario que esta so movendo o ticket filho.
  def move_parent_to_column(value)
    parent = ticket.parent
    return if parent.blank?

    target_column = parent.account.ticket_columns.find_by(id: value[:ticket_column_id])
    return if target_column.blank? || target_column == parent.ticket_column

    parent.move_to!(ticket_column: target_column, position: next_position(target_column))
  end

  def next_position(column)
    (column.tickets.maximum(:position) || -1) + 1
  end
end
