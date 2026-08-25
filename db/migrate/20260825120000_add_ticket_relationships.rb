class AddTicketRelationships < ActiveRecord::Migration[7.2]
  def change
    change_table :tickets, bulk: true do |t|
      # Parent/child. `nullify` rather than `cascade`: closing or deleting a
      # parent must never take its children's history with it.
      t.references :parent, foreign_key: { to_table: :tickets, on_delete: :nullify }, null: true
      # Grouping ("Agrupar ticket"): the ticket this one was merged into. The
      # merged ticket keeps every comment, attachment and activity it had - the
      # relation is what preserves access to them.
      t.references :merged_into, foreign_key: { to_table: :tickets, on_delete: :nullify }, null: true
      # The ticket's own deadline. Conversation SLA (AppliedSla) computes its
      # due dates on the fly from the conversation and cannot represent a
      # ticket, so the ticket carries its own.
      t.datetime :due_at
      t.datetime :cancelled_at
      # Why a ticket left the open state: 'merged', 'cancelled', or nil for a
      # plain close. Avoids inventing a global status per closing reason.
      t.string :close_reason
    end
  end
end
