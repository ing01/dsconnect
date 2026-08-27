# Aggregate counts for the "Central de Atendimento" dashboard, combining Conversation
# and Ticket data in one payload. The Ticket module has no reporting infrastructure of
# its own (never feeds ReportingEvent), so this stays intentionally simple - plain
# `group(...).count` queries rather than a new report-builder class.
class Api::V2::Accounts::HelpdeskOverviewController < Api::V1::Accounts::BaseController
  def show
    render json: {
      conversations: conversation_counts,
      tickets: ticket_counts,
      sla: sla_counts
    }
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def conversation_counts
    scope = Current.account.conversations
    {
      by_status: scope.group(:status).count,
      by_team: scope.where.not(team_id: nil).group(:team_id).count,
      by_queue: scope.where.not(queue_id: nil).group(:queue_id).count
    }
  end

  def ticket_counts
    scope = Current.account.tickets
    {
      by_status: scope.group(:status).count,
      by_team: scope.group(:team_id).count,
      by_column: scope.group(:ticket_column_id).count
    }
  end

  def sla_counts
    return {} unless Current.account.feature_enabled?('sla')

    { by_status: AppliedSla.where(account_id: Current.account.id).group(:sla_status).count }
  end
end
