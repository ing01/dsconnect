# A exportacao da Busca detalhada.
#
# Fica num concern porque o TicketsController ja carrega uma duzia de acoes e
# estava no limite de tamanho do projeto; alem disso, escolher formato e montar
# o anexo sao assunto proprio, nao do CRUD de tickets.
module TicketExporting
  extend ActiveSupport::Concern

  # A Busca detalhada em arquivo. Passa os mesmos parametros pelo mesmo
  # TicketFinder do `index`, entao o arquivo traz exatamente o que a tela
  # mostrou - sem a paginacao, que e da tela e nao do relatorio.
  def export
    exporter = Tickets::ExportService.new(
      account: Current.account, user: Current.user, params: params
    )

    return render_export_error(:empty) if exporter.count.zero?

    send_data(*export_payload(exporter))
  rescue Tickets::ExportService::TooManyRows
    render_export_error(:too_many, limit: Tickets::ExportService::MAX_ROWS)
  end

  private

  def render_export_error(reason, **)
    render json: { error: I18n.t("errors.ticket_export.#{reason}", **) },
           status: :unprocessable_entity
  end

  # Cada formato tem seu gerador; o conteudo vem do mesmo servico.
  def export_payload(exporter)
    return pdf_payload(exporter) if params[:format_type].to_s == 'pdf'

    xlsx_payload(exporter)
  end

  def pdf_payload(exporter)
    [
      Tickets::Export::PdfBuilder.new(
        export: exporter, generated_by: Current.user.name, account: Current.account
      ).render,
      { filename: export_filename('pdf'), type: 'application/pdf' }
    ]
  end

  def xlsx_payload(exporter)
    [
      Tickets::Export::XlsxBuilder.new(export: exporter).render,
      { filename: export_filename('xlsx'),
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
    ]
  end

  def export_filename(extension)
    "tickets-#{Time.current.strftime('%Y%m%d-%H%M')}.#{extension}"
  end
end
