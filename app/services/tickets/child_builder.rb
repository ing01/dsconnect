# Opens a child ticket from the values the creation form submitted, plus the
# parts of the parent the agent ticked that the form itself cannot express.
#
# The form is authoritative for every scalar field (title, description, Empresa,
# Solicitante, Mesa, Estagio, Categoria, Prioridade, Responsavel): the agent saw
# them pre-filled from the parent and may have changed any of them. `options`
# only drives the copies that happen server-side.
#
# What "copy" means differs per option, and the difference matters:
#   - Empresa, Solicitante and Seguidores REFERENCE the same records. Duplicating
#     a Company or a Contact would corrupt the customer base.
#   - Descricao is copied by VALUE, so editing the child never rewrites the parent.
#   - Arquivos are copied as new TicketAttachment rows each with their OWN blob
#     copy, so deleting a file from one ticket cannot detach it from the other.
#   - Comunicacao com cliente LINKS the same Conversations (ticket_conversations
#     is many-to-many). Messages are never re-inserted and nothing is ever sent
#     to the customer.
class Tickets::ChildBuilder
  COPYABLE = %w[title description company team assignee followers attachments comments conversations].freeze

  pattr_initialize [:parent!, :user!, :options!, :attributes!]

  def perform
    child = nil
    ActiveRecord::Base.transaction do
      child = create_child
      copy_followers(child)
      copy_attachments(child)
      copy_comments(child)
      link_conversations(child)
      log_activities(child)
    end
    child.reload
  end

  private

  def copy?(option)
    ActiveModel::Type::Boolean.new.cast(options[option.to_sym] || options[option.to_s])
  end

  def create_child
    parent.account.tickets.create!(base_attributes)
  end

  def base_attributes
    {
      parent: parent,
      title: attributes[:title].presence || default_title,
      description: attributes[:description],
      # References the same Empresa - never a duplicated Company row.
      company_id: attributes[:company_id],
      contact_id: attributes[:contact_id],
      ticket_category_id: attributes[:ticket_category_id],
      priority: attributes[:priority].presence || parent.priority
    }.merge(placement)
  end

  def default_title
    "#{parent.title} (#{I18n.t('tickets.child_suffix', default: 'ticket filho')})"
  end

  # A ticket cannot exist without a Mesa and an Estagio. Copying the Mesa reuses
  # the parent's, and the child lands in that Mesa's FIRST Estagio rather than
  # the parent's current one - a child starts its own workflow, it does not
  # resume the parent's halfway through.
  # The form sends the Mesa and the Estagio it showed; only the fallbacks come
  # from the parent.
  def placement
    team = resolved_team
    column = resolved_column(team) || team.ticket_columns.order(:position, :id).first
    raise ActiveRecord::RecordInvalid, parent if column.blank?

    { team: team, ticket_column: column, assignee_id: assignee_id_for(team) }
  end

  def resolved_team
    return parent.account.teams.find(attributes[:team_id]) if attributes[:team_id].present?

    parent.team
  end

  def resolved_column(team)
    return if attributes[:ticket_column_id].blank?

    team.ticket_columns.find_by(id: attributes[:ticket_column_id])
  end

  # The Mesa owns who may be assigned, so a Responsavel who is not a member of
  # the Mesa the child lands in is dropped rather than carried over.
  def assignee_id_for(team)
    candidate = attributes[:assignee_id].presence
    return if candidate.blank?

    candidate if team.members.exists?(id: candidate)
  end

  def copy_followers(child)
    return unless copy?(:followers)

    parent.ticket_followers.find_each do |follower|
      child.ticket_followers.create!(account_id: child.account_id, user_id: follower.user_id)
    end
  end

  # Each attachment gets its own blob copy. Sharing one blob between two
  # TicketAttachment rows would make purging the file from one ticket break the
  # other, which is exactly what the spec forbids.
  def copy_attachments(child)
    return unless copy?(:attachments)

    parent.ticket_attachments.each do |attachment|
      next unless attachment.file.attached?

      copy = child.ticket_attachments.new(account_id: child.account_id, user_id: attachment.user_id)
      # `blob.open` streams to a tempfile instead of loading the whole file into
      # memory, which matters at the 40 MB attachment limit.
      attachment.file.blob.open do |file|
        copy.file.attach(
          io: file,
          filename: attachment.file.filename.to_s,
          content_type: attachment.file.content_type
        )
      end
      copy.save!
    end
  end

  # Internal communication is TicketComment: agent-authored notes on the ticket.
  # Only the content and author are carried over - notifications, read states and
  # the activity trail belong to the parent's own history.
  def copy_comments(child)
    return unless copy?(:comments)

    parent.ticket_comments.order(:created_at).each do |comment|
      child.ticket_comments.create!(account_id: child.account_id, user_id: comment.user_id, content: comment.content)
    end
  end

  # Links, never duplicates. `ticket_conversations` is a join table, so the same
  # Conversation can belong to both tickets and no message is re-inserted.
  def link_conversations(child)
    return unless copy?(:conversations)

    parent.ticket_conversations.each do |link|
      child.ticket_conversations.create!(account_id: child.account_id, conversation_id: link.conversation_id)
    end
  end

  def log_activities(child)
    parent.ticket_activities.create!(
      account_id: parent.account_id, user: user, activity_type: :child_created,
      new_value: child.display_id.to_s, meta: { ticket_id: child.id, options: options }
    )
    child.ticket_activities.create!(
      account_id: child.account_id, user: user, activity_type: :parent_changed,
      new_value: parent.display_id.to_s, meta: { ticket_id: parent.id }
    )
  end
end
