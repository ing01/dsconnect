# Garante que a conta tenha os tres niveis iniciais de Complexidade - chamado ao
# LISTAR, como Suggestions::DefaultColumnsBuilder, para a tela nunca abrir vazia
# numa conta que existe desde antes desta funcionalidade.
#
# Idempotente, e deliberadamente cego ao conteudo: uma conta que JA tem qualquer
# Complexidade e um no-op. Quem renomeou "Medio" para "Moderado" ou apagou um
# nivel nao o vera voltar na proxima visita.
#
# E o unico lugar do sistema que menciona estes nomes. Dali em diante a lista e
# so dado: criar, renomear, reordenar e desligar niveis nao pede codigo.
class Tickets::DefaultComplexitiesBuilder
  pattr_initialize [:account!]

  DEFAULT_NAMES = %w[Baixo Médio Alto].freeze

  def perform
    return if account.ticket_complexities.exists?

    DEFAULT_NAMES.each_with_index do |name, index|
      complexity = account.ticket_complexities.create!(name: name, position: index)
      # Toda Mesa oferece os tres no comeco: a configuracao existe para
      # RESTRINGIR, e comecar com tudo desmarcado deixaria os tickets sem opcao
      # nenhuma no dia da atualizacao.
      complexity.replace_teams!(account.team_ids)
    end
  end
end
