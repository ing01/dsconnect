# Os niveis de responsavel de uma Mesa de Servico.
#
# Um so lugar define quais niveis existem e o que cada um significa. Hoje sao
# dois - Nivel 1 atende, Nivel 2 analisa o que foi escalado -, e acrescentar um
# terceiro e incluir o numero em LEVELS: nem a Mesa, nem o ticket, nem o
# apontamento tem coluna por nivel.
module AssigneeLeveled
  extend ActiveSupport::Concern

  LEVELS = [1, 2].freeze
  FIRST_LEVEL = 1
  SECOND_LEVEL = 2

  def self.valid_level?(level)
    LEVELS.include?(level.to_i)
  end

  # O campo do ticket que guarda o responsavel de cada nivel.
  #
  # O Nivel 1 e o `assignee_id` que sempre existiu: a policy, os filtros e o
  # "assumir ticket" ja o usam, e reinterpretar em vez de trocar mantem tudo
  # isso valendo sem adaptacao.
  def self.assignee_column(level)
    level.to_i == FIRST_LEVEL ? :assignee_id : :assignee_2_id
  end
end
