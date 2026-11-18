# Mesmo padrao do `ticket_customer_communication_id` ja existente - um anexo
# agora tambem pode vir de um Comentario interno, nao so de uma Comunicacao
# com o Cliente (pedido da Ingrid, 2026-11-18: anexo nos dois tipos).
class AddTicketCommentToTicketAttachments < ActiveRecord::Migration[7.2]
  def change
    add_reference :ticket_attachments, :ticket_comment, foreign_key: true, index: true
  end
end
