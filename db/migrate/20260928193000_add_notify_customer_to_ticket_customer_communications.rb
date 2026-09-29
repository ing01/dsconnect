# Nem toda comunicacao precisa sair por e-mail: a mensagem sempre aparece para o
# cliente na Area do Cliente, e as vezes a equipe ja falou com ele por telefone
# ou WhatsApp e quer apenas registrar isso no chamado.
#
# Default true preserva o comportamento de hoje - tudo que ja existe foi enviado
# por e-mail, e quem nao mexer no campo continua enviando.
class AddNotifyCustomerToTicketCustomerCommunications < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_customer_communications, :notify_customer, :boolean, default: true, null: false
  end
end
