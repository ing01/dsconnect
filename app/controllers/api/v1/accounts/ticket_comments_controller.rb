class Api::V1::Accounts::TicketCommentsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_ticket_comment, only: [:destroy]
  before_action :check_authorization

  def index
    @ticket_comments = @ticket.ticket_comments.includes(:user).order(created_at: :asc)
  end

  def create
    ActiveRecord::Base.transaction do
      @ticket_comment = @ticket.ticket_comments.new(ticket_comment_params.except(:attachments).merge(user: Current.user))
      @ticket_comment.save!
      attach_uploaded_files!
    end
  end

  def destroy
    @ticket_comment.destroy!
    head :ok
  end

  private

  # TicketCommentPolicy#destroy? checks the comment's author, so it needs the
  # loaded instance rather than the bare `TicketComment` class.
  def check_authorization(model = nil)
    super(model || @ticket_comment || TicketComment)
  end

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_ticket_comment
    @ticket_comment = @ticket.ticket_comments.find(params[:id])
  end

  def ticket_comment_params
    params.require(:ticket_comment).permit(:content, attachments: [])
  end

  def attach_uploaded_files!
    Array(ticket_comment_params[:attachments]).reject(&:blank?).each do |arquivo|
      anexo = @ticket.ticket_attachments.new(account_id: @ticket.account_id, user: Current.user, ticket_comment: @ticket_comment)
      anexo.file.attach(arquivo)
      anexo.save!
    end
  end
end
