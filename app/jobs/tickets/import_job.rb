# Roda Tickets::ImportService em segundo plano (Sidekiq) - uma planilha real
# pode ter dezenas de milhares de linhas, tempo demais pra uma unica
# requisicao web aguentar. Ver TicketImport (registro de progresso/resultado
# que a tela consulta) e Api::V1::Accounts::TicketImportsController.
class Tickets::ImportJob < ApplicationJob
  queue_as :low

  def perform(ticket_import_id)
    ticket_import = TicketImport.find(ticket_import_id)
    ticket_import.update!(status: :processing)

    result = Tickets::ImportService.new(
      account: ticket_import.account, csv_content: read_csv_content(ticket_import), ticket_import: ticket_import
    ).perform

    ticket_import.update!(
      status: :completed, created_count: result.created, updated_count: result.updated, skipped_count: result.skipped,
      row_errors: result.errors, row_warnings: result.warnings
    )
  rescue StandardError => e
    ticket_import&.update!(status: :failed, failure_message: e.message)
    ChatwootExceptionTracker.new(e, account: ticket_import&.account).capture_exception
  end

  private

  # Mesma correcao de encoding que a planilha exige: quase sempre vem em
  # Windows-1252/ISO-8859-1 de um export no Windows, nunca UTF-8 de verdade -
  # e o Excel costuma gravar um BOM na frente do "CSV UTF-8".
  def read_csv_content(ticket_import)
    raw = ticket_import.file.download
    content = if raw.dup.force_encoding('UTF-8').valid_encoding?
                raw.force_encoding('UTF-8')
              else
                raw.force_encoding('Windows-1252').encode('UTF-8')
              end
    content.delete_prefix("﻿")
  end
end
