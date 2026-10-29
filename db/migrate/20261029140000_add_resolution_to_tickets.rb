# A Resolucao do ticket: o que foi feito para resolver, escrito por quem fecha.
#
# E' exigida no fechamento (ver TicketClosing) e e' o que alimenta a base de
# conhecimento - o DueRules e a documentacao aprendem com o que a equipe
# realmente fez, e nao so' com o que o cliente pediu. Opcional na coluna: todo
# ticket que ja existe continua valido sem ela, e a exigencia aparece so' ao
# fechar.
class AddResolutionToTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :tickets, :resolution, :text
  end
end
