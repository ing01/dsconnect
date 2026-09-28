# Garante que a conta tenha as colunas padrao do quadro de Sugestoes - chamado
# tanto ao listar as colunas quanto ao enviar a primeira sugestao, pra nenhum
# dos dois caminhos esbarrar num quadro vazio. Idempotente: um account com
# colunas (quaisquer, nao so as padrao - o admin pode ja ter mexido) e um
# no-op.
class Suggestions::DefaultColumnsBuilder
  pattr_initialize [:account!]

  DEFAULT_COLUMN_NAMES = ['Ideias', 'Em análise', 'Planejado', 'Em desenvolvimento', 'Concluído'].freeze

  def perform
    return if account.suggestion_columns.exists?

    DEFAULT_COLUMN_NAMES.each { |name| account.suggestion_columns.create!(name: name) }
  end
end
