# Suporte a MAIS de um representante legal por cliente. Decisao (confirmada
# com a Ingrid): duplicar automaticamente um bloco inteiro do contrato para
# cada representante extra e' um risco alto para pouco ganho sem conseguir
# testar localmente (o .docx real pode quebrar a formatacao do jeito mais
# inesperado) - ela proprio topou o caminho mais simples:
#
# - `extra_representatives` guarda os representantes ALEM do primeiro
#   (campos `representative_*` ja existentes), so para referencia/consulta -
#   NUNCA entram no contrato gerado automaticamente.
# - O contrato gerado passa a guardar tambem o .docx preenchido (so' com o
#   primeiro representante), nao so' o PDF - para ela abrir no Word e
#   acrescentar os demais representantes a mao antes de converter/assinar.
class AddExtraRepresentativesAndDocxToCrm < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_clients, :extra_representatives, :jsonb, null: false, default: []
  end
end
