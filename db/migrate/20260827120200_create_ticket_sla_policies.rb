# A matriz Mesa x Prioridade: um prazo de atendimento e um de solucao para cada
# prioridade da Mesa. SlaPolicy (das Conversations) e por conta e nao comporta
# essa granularidade, por isso a tabela propria - mas os limiares seguem a mesma
# unidade dela, segundos.
class CreateTicketSlaPolicies < ActiveRecord::Migration[7.0]
  def change
    create_table :ticket_sla_policies do |t|
      t.references :account, null: false, index: true
      t.references :team, null: false, index: false
      t.integer :priority, null: false
      t.float :response_threshold
      t.float :resolution_threshold
      t.boolean :only_during_business_hours, default: true, null: false

      t.timestamps
    end

    add_index :ticket_sla_policies, %i[team_id priority], unique: true
  end
end
