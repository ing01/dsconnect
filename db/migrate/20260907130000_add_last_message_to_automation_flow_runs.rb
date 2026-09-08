# Qual mensagem do cliente a execucao ja consumiu.
#
# Sem isto, a mesma mensagem pode ser processada duas vezes quando dois eventos
# chegam juntos: o bot responderia em dobro e a etapa avancaria duas casas. O
# indice unico impede duas execucoes, mas nao impede a mesma execucao ler o
# mesmo texto duas vezes.
class AddLastMessageToAutomationFlowRuns < ActiveRecord::Migration[7.2]
  def change
    add_column :automation_flow_runs, :last_message_id, :bigint
  end
end
