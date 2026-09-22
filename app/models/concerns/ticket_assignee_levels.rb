# O lado Ticket dos niveis de responsavel.
#
# Vale apenas onde a Mesa ligou a configuracao, e so ate a quantidade de niveis
# que ELA usa. Sem a configuracao o ticket responde como sempre respondeu: um
# responsavel so, e nenhum destes metodos muda nada.
module TicketAssigneeLevels
  extend ActiveSupport::Concern

  included do
    validate :assignee_levels_supported_by_team
    validate :assignees_allowed_in_their_levels
  end

  def assignee_levels_enabled?
    team&.assignee_levels_enabled?
  end

  # Os niveis deste ticket sao os da Mesa dele: uma Mesa em tres niveis mostra
  # tres campos, a de dois mostra dois.
  def assignee_levels
    team&.assignee_levels || [AssigneeLeveled::FIRST_LEVEL]
  end

  def assignee_for_level(level)
    public_send(AssigneeLeveled.assignee_association(level))
  end

  # Em que nivel esta pessoa atua NESTE ticket. Nulo quando ela nao e nenhum dos
  # responsaveis - alguem que aponta horas sem ser responsavel nao pertence a
  # nivel nenhum, e o apontamento fica sem nivel em vez de ganhar um errado.
  def level_of(user_id)
    return if user_id.blank?

    assignee_levels.find { |level| self[AssigneeLeveled.assignee_column(level)] == user_id }
  end

  # Quanto tempo cada nivel gastou neste ticket, com quem respondeu por ele.
  # E a resposta de "quanto o Nivel 1 gastou no atendimento e o Nivel 2 na
  # analise" para um ticket.
  def hours_by_level
    # `reorder(nil)` porque a associacao ja vem ordenada por data, e um ORDER BY
    # com GROUP BY exige a coluna no agrupamento - o Postgres recusa.
    totals = ticket_time_entries.reorder(nil).group(:level).sum(:hours)

    assignee_levels.index_with do |level|
      { assignee: assignee_for_level(level), hours: totals[level] || 0 }
    end
  end

  private

  # Nao adianta indicar um Nivel 3 numa Mesa que atende em dois, nem qualquer
  # nivel numa Mesa que nao usa niveis: o campo nem aparece na tela, e o valor
  # ficaria invisivel no registro.
  def assignee_levels_supported_by_team
    niveis_da_mesa = assignee_levels

    (AssigneeLeveled::MIN_LEVEL..AssigneeLeveled::MAX_LEVEL).each do |level|
      column = AssigneeLeveled.assignee_column(level)
      next if self[column].blank? || niveis_da_mesa.include?(level)

      errors.add(column, mensagem_de_nivel_indisponivel(level))
    end
  end

  # Duas causas diferentes, duas mensagens: a Mesa nao usa niveis nenhum, ou usa
  # menos niveis do que este. Quem le a mensagem precisa saber o que configurar.
  def mensagem_de_nivel_indisponivel(level)
    return I18n.t('tickets.assignee_levels.not_enabled') unless assignee_levels_enabled?

    I18n.t('tickets.assignee_levels.beyond_count', level: level, count: team.assignee_levels_count)
  end

  # A permissao e da Mesa: quem nao esta habilitado num nivel nao pode ocupa-lo.
  # Checado aqui, e nao so na tela, porque a tela e conveniencia e esta regra
  # precisa valer para a API tambem.
  def assignees_allowed_in_their_levels
    return unless assignee_levels_enabled?

    assignee_levels.each { |level| validate_level_assignee(level) }
  end

  def validate_level_assignee(level)
    column = AssigneeLeveled.assignee_column(level)

    # So valida quem esta sendo ATRIBUIDO agora. Validando a cada salvamento, um
    # ticket antigo cujo responsavel nao foi cadastrado no nivel ficava
    # impossivel de salvar - e nao so para trocar o responsavel: fechar,
    # cancelar, transferir ou impedir tambem passam por `save`, e todos
    # quebravam por um dado que o usuario nem estava tocando.
    return unless new_record? || will_save_change_to_attribute?(column)

    user_id = self[column]
    return if user_id.blank?
    return if team.members_for_level(level).exists?(id: user_id)

    errors.add(column, I18n.t('tickets.assignee_levels.not_allowed', level: level))
  end
end
