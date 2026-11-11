# As horas dos apontamentos eram guardadas com 2 casas (0,01 h = 36 s). Um apontamento de
# 1 minuto virava 0,02 h e um de 40 segundos virava 0,01 h: cada lancamento perdia ate
# 18 s e os totais nao batiam com o que o cronometro marcou (1 min + 2 min dava 2 min).
#
# Com 4 casas o erro por lancamento cai para menos de 0,2 s. So alarga a coluna: os
# valores que ja existem continuam iguais (ficam como foram gravados) e os relatorios que
# somam `hours` seguem funcionando.
class WidenTicketTimeEntriesHours < ActiveRecord::Migration[7.2]
  def up
    change_column :ticket_time_entries, :hours, :decimal, precision: 8, scale: 4, null: false
  end

  def down
    change_column :ticket_time_entries, :hours, :decimal, precision: 6, scale: 2, null: false
  end
end
