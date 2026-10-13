# Log de importacao de tickets: agora um arquivo pode ATUALIZAR um ticket ja
# importado (nao so' criar/pular), por isso a contagem propria
# `updated_count` - nao cabe em `created_count` nem em `skipped_count`.
# `user_id` registra quem disparou a importacao, pro log mostrar isso tambem
# (Configuracoes > Tickets > Importar).
class AddLogFieldsToTicketImports < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_imports, :updated_count, :integer, default: 0, null: false
    add_reference :ticket_imports, :user, null: true, foreign_key: true, index: true
  end
end
