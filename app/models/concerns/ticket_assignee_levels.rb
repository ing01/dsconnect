# O lado Ticket dos niveis de responsavel.
#
# Vale apenas onde a Mesa ligou a configuracao. Sem ela o ticket responde como
# sempre respondeu: um responsavel so, e nenhum destes metodos muda nada.
module TicketAssigneeLevels
  extend ActiveSupport::Concern

  included do
    validate :assignee_levels_supported_by_team
    validate :assignees_allowed_in_their_levels
  end

  def assignee_levels_enabled?
    team&.assignee_levels_enabled?
  end

  def assignee_for_level(level)
    public_send(AssigneeLeveled.assignee_column(level).to_s.delete_suffix('_id'))
  end

  # Em que nivel esta pessoa atua NESTE ticket. Nulo quando ela nao e nenhum dos
  # responsaveis - alguem que aponta horas sem ser responsavel nao pertence a
  # nivel nenhum, e o apontamento fica sem nivel em vez de ganhar um errado.
  def level_of(user_id)
    return if user_id.blank?

    AssigneeLeveled::LEVELS.find do |level|
      self[AssigneeLeveled.assignee_column(level)] == user_id
    end
  end

  # Quanto tempo cada nivel gastou neste ticket, com quem respondeu por ele.
  # E a resposta de "quanto o Nivel 1 gastou no atendimento e o Nivel 2 na
  # analise" para um ticket.
  def hours_by_level
    # `reorder(nil)` porque a associacao ja vem ordenada por data, e um ORDER BY
    # com GROUP BY exige a coluna no agrupamento - o Postgres recusa.
    totals = ticket_time_entries.reorder(nil).group(:level).sum(:hours)

    AssigneeLeveled::LEVELS.index_with do |level|
      { assignee: assignee_for_level(level), hours: totals[level] || 0 }
    end
  end

  private

  # Nao adianta indicar um Nivel 2 numa Mesa que nao usa niveis: o campo nem
  # aparece na tela, e o valor ficaria invisivel no registro.
  def assignee_levels_supported_by_team
    return if assignee_2_id.blank? || assignee_levels_enabled?

    errors.add(:assignee_2_id, I18n.t('tickets.assignee_levels.not_enabled'))
  end

  # A permissao e da Mesa: quem nao esta habilitado num nivel nao pode ocupa-lo.
  # Checado aqui, e nao so na tela, porque a tela e conveniencia e esta regra
  # precisa valer para a API tambem.
  def assignees_allowed_in_their_levels
    return unless assignee_levels_enabled?

    AssigneeLeveled::LEVELS.each { |level| validate_level_assignee(level) }
  end

  def validate_level_assignee(level)
    column = AssigneeLeveled.assignee_column(level)
    user_id = self[column]
    return if user_id.blank?
    return if team.members_for_level(level).exists?(id: user_id)

    errors.add(column, I18n.t('tickets.assignee_levels.not_allowed', level: level))
  end
end
