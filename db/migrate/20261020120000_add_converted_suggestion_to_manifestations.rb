class AddConvertedSuggestionToManifestations < ActiveRecord::Migration[7.1]
  def change
    # Espelha `converted_ticket_id`: uma manifestacao vira UM dos dois (ticket
    # OU sugestao), nunca os dois - `Manifestation#converted?` passa a olhar
    # qualquer um dos dois para continuar recusando a segunda conversao.
    add_reference :manifestations, :converted_suggestion, foreign_key: { to_table: :suggestions }, index: true
  end
end
