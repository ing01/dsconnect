# Acompanha uma importacao de tickets via CSV (Configuracoes > Tickets >
# Importar) rodando em segundo plano - Tickets::ImportJob/Tickets::ImportService.
# O arquivo enviado fica anexado via ActiveStorage (`has_one_attached :file`
# em TicketImport), pra o job conseguir ler o conteudo fora da requisicao web
# que recebeu o upload.
class CreateTicketImports < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_imports do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.integer :total_rows
      t.integer :processed_rows, default: 0, null: false
      t.integer :created_count, default: 0, null: false
      t.integer :skipped_count, default: 0, null: false
      # Nao chamado `errors`/`warnings`: colidiria com o `errors` que todo
      # ActiveModel ja tem embutido pra validacao.
      t.jsonb :row_errors, default: [], null: false
      t.jsonb :row_warnings, default: [], null: false
      t.text :failure_message

      t.timestamps
    end
  end
end
