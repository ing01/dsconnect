# Categoria que exige anexo.
#
# "Erro" quase sempre precisa de print ou log para ser investigado; "Duvida",
# nao. Como isso varia por Mesa e por Categoria, e configuracao - nao regra no
# codigo.
class AddRequireAttachmentToTicketCategories < ActiveRecord::Migration[7.2]
  def change
    # Desligado por padrao: nenhuma Categoria que ja existe passa a exigir nada.
    add_column :ticket_categories, :require_attachment, :boolean, default: false, null: false
  end
end
