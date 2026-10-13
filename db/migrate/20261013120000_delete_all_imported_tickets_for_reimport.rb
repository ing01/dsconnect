# A Ingrid reimportou um lote grande de tickets depois do fix que faz o
# "Numero" da planilha virar o `display_id` de verdade (ver
# Tickets::ImportService). Varias linhas falharam com "Numero ja pertence a
# outro ticket nesta conta": os proprios tickets importados ANTES desse fix
# ainda estavam com um display_id sequencial antigo (gerado pelo Chatwoot),
# "ocupando" o numero que agora pertence de verdade a outro ticket do mesmo
# lote - uma renumeracao em massa colide assim quando os tickets antigos
# ficam no caminho dos novos numeros.
#
# Apaga TODO ticket que ja foi importado (tem
# `custom_attributes['imported_ticket_number']`), de qualquer Mesa, pra uma
# reimportacao comecar do zero sem nenhum numero antigo no caminho. So' os
# importados - ticket aberto manualmente no sistema nunca tem essa chave e
# fica intocado. Pedido explicito da Ingrid, ciente de que isso apaga os
# dados (ela vai reimportar as planilhas de origem em seguida).
class DeleteAllImportedTicketsForReimport < ActiveRecord::Migration[7.2]
  def up
    scope = Ticket.where("custom_attributes ->> 'imported_ticket_number' IS NOT NULL")
    total = scope.count
    Rails.logger.info("[DeleteAllImportedTicketsForReimport] apagando #{total} ticket(s) importado(s)")

    scope.find_each(&:destroy!)
  end

  def down
    # Sem volta - os dados foram apagados de proposito pra reimportar.
  end
end
