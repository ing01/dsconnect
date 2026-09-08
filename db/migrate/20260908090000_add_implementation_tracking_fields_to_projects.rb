class AddImplementationTrackingFieldsToProjects < ActiveRecord::Migration[7.2]
  def change
    add_reference :projects, :implementer, foreign_key: { to_table: :users }, index: true
    add_column :projects, :cancelled_at, :datetime
    add_column :projects, :cancellation_reason, :text
    add_column :projects, :completion_type, :string
    add_column :projects, :notes, :text
    add_column :projects, :support_ends_on, :date
    add_column :projects, :contract_signed_on, :date
  end
end
