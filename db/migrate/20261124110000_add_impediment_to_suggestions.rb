# Impedimento de sugestao: quem gerencia o quadro marca que a sugestao nao pode
# andar sem mais detalhes de quem a abriu. Mesmo formato do impedimento de
# ticket: `blocked_at` presente E o estado impedido, sem booleano ao lado.
class AddImpedimentToSuggestions < ActiveRecord::Migration[7.2]
  def change
    add_column :suggestions, :blocked_at, :datetime
    add_column :suggestions, :blocked_reason, :text
    add_reference :suggestions, :blocked_by, foreign_key: { to_table: :users }, null: true, index: false
  end
end
