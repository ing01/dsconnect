# O relatorio "Chat detalhado": uma linha por conversa, com um resumo do periodo, e a
# mesma coisa em Excel (duas abas: Chat Detalhado e Resumo).
#
# Somente leitura. Os filtros sao todos opcionais e se acumulam.
class Api::V1::Accounts::ChatDetailReportsController < Api::V1::Accounts::BaseController
  PER_PAGE = 25

  before_action :check_authorization
  rescue_from ChatDetailReport::Builder::TooManyRows, with: :render_too_many_rows

  def index
    result = builder.page(page: page, per_page: PER_PAGE)
    render json: {
      payload: result[:rows], summary: result[:summary],
      columns: ChatDetailReport::Builder::COLUMNS.map { |key, label| { key: key, label: label } },
      summary_columns: ChatDetailReport::Builder::SUMMARY_COLUMNS.map { |key, label| { key: key, label: label } },
      meta: { count: result[:total], page: page, per_page: PER_PAGE }
    }
  end

  def export
    send_data(
      ChatDetailReport::XlsxBuilder.new(builder: builder).render,
      filename: "chat-detalhado-#{Time.current.strftime('%Y%m%d-%H%M')}.xlsx",
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def builder
    @builder ||= ChatDetailReport::Builder.new(account: Current.account, params: report_params)
  end

  def page
    [params[:page].to_i, 1].max
  end

  def report_params
    params.permit(:from, :to, :assignee_id, :team_id, :inbox_id, :queue_id, :status, :company_id)
  end

  def render_too_many_rows
    render json: { error: I18n.t('errors.chat_detail_report.too_many_rows', limit: ChatDetailReport::Builder::MAX_ROWS) },
           status: :unprocessable_entity
  end
end
