# Guarantees an account opening the Kanban always has at least one usable Mesa de
# Servico. Returns the account's existing Mesa when there is one - never renaming
# or touching it - and otherwise provisions 'suporte', whose default Estagios come
# from Team#provision_default_ticket_columns.
#
# Idempotency under concurrency is delegated to the database: two simultaneous
# first loads both attempt the INSERT, the unique index on (name, account_id) lets
# exactly one through, and the loser re-reads the winner's row.
class Tickets::DefaultMesaBuilder
  DEFAULT_MESA_NAME = 'suporte'.freeze

  pattr_initialize [:account!]

  def perform
    existing_mesa = account.teams.order(:id).first
    return existing_mesa if existing_mesa.present?

    create_default_mesa
  end

  private

  def create_default_mesa
    account.teams.create!(name: DEFAULT_MESA_NAME)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    account.teams.find_by!(name: DEFAULT_MESA_NAME)
  end
end
