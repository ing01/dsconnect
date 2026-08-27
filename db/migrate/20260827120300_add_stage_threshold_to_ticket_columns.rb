# O prazo do Estagio mora junto do cadastro do Estagio, como pedido: nulo
# significa "esta coluna nao tem prazo", nao zero.
class AddStageThresholdToTicketColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :ticket_columns, :stage_threshold, :float
  end
end
