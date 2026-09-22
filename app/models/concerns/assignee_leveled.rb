# Os niveis de responsavel de uma Mesa de Servico.
#
# Um so lugar define como um nivel virou dado. QUANTOS niveis existem nao mora
# aqui: e configuracao de cada Mesa (`teams.assignee_levels_count`), porque a
# Mesa de Suporte pode atender em tres niveis enquanto a de Infra atende em dois.
# Este modulo define apenas o teto e onde cada nivel e gravado.
module AssigneeLeveled
  extend ActiveSupport::Concern

  # Quantos niveis o sistema sabe guardar. O ticket tem uma coluna por nivel ate
  # aqui, criadas de uma vez: subir uma Mesa para o Nivel 3 e configuracao, nao
  # migracao. Passar deste teto sim exigiria colunas novas.
  MAX_LEVEL = 5
  # O minimo faz parte do contrato: uma Mesa "com niveis" que usasse um so nivel
  # seria a Mesa sem niveis, escrita de outro jeito.
  MIN_LEVEL = 2
  ALL_LEVELS = (1..MAX_LEVEL).to_a.freeze
  FIRST_LEVEL = 1

  def self.valid_level?(level)
    ALL_LEVELS.include?(level.to_i)
  end

  # O campo do ticket que guarda o responsavel de cada nivel.
  #
  # O Nivel 1 e o `assignee_id` que sempre existiu: a policy, os filtros e o
  # "assumir ticket" ja o usam, e reinterpretar em vez de trocar mantem tudo
  # isso valendo sem adaptacao. Do 2 em diante, uma coluna por nivel.
  def self.assignee_column(level)
    level.to_i == FIRST_LEVEL ? :assignee_id : :"assignee_#{level.to_i}_id"
  end

  # A associacao correspondente - o que o serializer le e o que o `includes`
  # precisa pre-carregar para a listagem nao virar um N+1 por ticket.
  def self.assignee_association(level)
    assignee_column(level).to_s.delete_suffix('_id').to_sym
  end

  # Todas as associacoes de responsavel, do 1 ao teto. Vai inteira para o
  # `includes`: o payload emite so os niveis que a Mesa usa, mas cada Mesa usa
  # uma quantidade diferente e a consulta e uma so para todas.
  def self.assignee_associations
    ALL_LEVELS.map { |level| assignee_association(level) }
  end
end
