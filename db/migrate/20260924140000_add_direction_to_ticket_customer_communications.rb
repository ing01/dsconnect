# A comunicacao do ticket passa a ter DOIS sentidos.
#
# Ate aqui a tabela guardava so o que a equipe enviava ao cliente. Com a Area do
# Cliente, o cliente tambem responde - e a resposta pertence a mesma conversa,
# nao a uma tabela nova: e o mesmo assunto, no mesmo ticket, lido pelas duas
# partes na mesma aba.
class AddDirectionToTicketCustomerCommunications < ActiveRecord::Migration[7.2]
  def change
    # Tudo que existe foi enviado AO cliente, entao o padrao mantem o historico
    # correto sem precisar tocar em nenhuma linha.
    add_column :ticket_customer_communications, :direction, :string,
               default: 'outbound', null: false
    add_index :ticket_customer_communications, [:ticket_id, :direction]

    # `to_email` era obrigatorio porque toda linha era um e-mail SAINDO. A
    # mensagem que chega nao tem destinatario a preencher - e inventar um
    # (o proprio cliente? a Mesa?) seria gravar um dado que ninguem usa.
    change_column_null :ticket_customer_communications, :to_email, true

    # O arquivo que veio junto da mensagem. Nulo no anexo solto do ticket, que
    # continua existindo - e o vinculo que permite mostrar "estes arquivos
    # vieram com esta mensagem" em vez de uma pilha sem dono.
    add_reference :ticket_attachments, :ticket_customer_communication,
                  foreign_key: true, null: true, index: false
    add_index :ticket_attachments, :ticket_customer_communication_id,
              where: 'ticket_customer_communication_id IS NOT NULL',
              name: 'index_ticket_attachments_on_communication'
  end
end
