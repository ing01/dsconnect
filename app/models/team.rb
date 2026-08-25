# == Schema Information
#
# Table name: teams
#
#  id                :bigint           not null, primary key
#  allow_auto_assign :boolean          default(TRUE)
#  description       :text
#  icon              :string           default("")
#  icon_color        :string           default("")
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_teams_on_account_id           (account_id)
#  index_teams_on_name_and_account_id  (name,account_id) UNIQUE
#
class Team < ApplicationRecord
  include AccountCacheRevalidator

  belongs_to :account
  has_many :team_members, dependent: :destroy_async
  has_many :members, through: :team_members, source: :user
  has_many :conversations, dependent: :nullify
  # A Team is the "Mesa de Servico" a ticket belongs to; its Estagios
  # (`ticket_columns`) are meaningless without it, so they're destroyed
  # alongside it. Tickets, on the other hand, must never be silently
  # orphaned/reassigned - a Mesa with open tickets can't be deleted until
  # those tickets are moved or removed first.
  has_many :ticket_columns, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :team
  # Categories are scoped to the Mesa the same way Estagios are, and are just as
  # meaningless without it.
  has_many :ticket_categories, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :team
  has_many :tickets, dependent: :restrict_with_error
  has_many :calendar_events, dependent: :destroy

  before_destroy :capture_filtered_unread_count_member_ids, prepend: true
  after_destroy_commit :invalidate_filtered_unread_counts_after_destroy
  after_create_commit :provision_default_ticket_columns, :provision_default_ticket_categories

  validates :name,
            presence: { message: I18n.t('errors.validations.presence') },
            uniqueness: { scope: :account_id }

  before_validation do
    self.name = name.gsub(/[[:cntrl:]]/, '').strip.downcase if attribute_present?('name')
  end

  # Adds multiple members to the team
  # @param user_ids [Array<Integer>] Array of user IDs to add as members
  # @return [Array<User>] Array of newly added members
  def add_members(user_ids)
    team_members_to_create = user_ids.map { |user_id| { user_id: user_id } }
    created_members = team_members.create(team_members_to_create)
    added_users = created_members.filter_map(&:user)

    update_account_cache
    added_users
  end

  # Removes multiple members from the team
  # @param user_ids [Array<Integer>] Array of user IDs to remove
  # @return [void]
  def remove_members(user_ids)
    team_members.where(user_id: user_ids).destroy_all
    update_account_cache
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  def push_event_data
    {
      id: id,
      name: name,
      icon: icon,
      icon_color: icon_color
    }
  end

  private

  # Every Mesa de Servico needs at least one Estagio to be usable in the
  # Kanban, so new Teams are provisioned with a sensible default set that
  # admins can then rename/reorder/extend freely (see TicketColumnsController).
  DEFAULT_TICKET_COLUMN_NAMES = ['A fazer', 'Em andamento', 'Concluído'].freeze

  def provision_default_ticket_columns
    DEFAULT_TICKET_COLUMN_NAMES.each { |column_name| ticket_columns.create!(name: column_name) }
  end

  # Category is mandatory on a new ticket, so a Mesa with an empty list would be
  # a Mesa nobody can open a ticket in. Admins rename/reorder/extend these
  # freely (see TicketCategoriesController).
  DEFAULT_TICKET_CATEGORY_NAMES = %w[Dúvida Erro Homologação Instalação Melhoria Treinamento].freeze

  def provision_default_ticket_categories
    DEFAULT_TICKET_CATEGORY_NAMES.each { |category_name| ticket_categories.create!(name: category_name) }
  end

  def capture_filtered_unread_count_member_ids
    @filtered_unread_count_member_ids = team_members.pluck(:user_id)
  end

  def invalidate_filtered_unread_counts_after_destroy
    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    invalidator.conversation_changed!
    invalidator.users_visibility_changed!(user_ids: @filtered_unread_count_member_ids)
  end
end

Team.include_mod_with('Audit::Team')
