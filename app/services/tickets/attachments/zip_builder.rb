# O .zip do botao "Baixar todos" na aba de Arquivos do Ticket.
#
# Monta tudo em memoria (igual Tickets::Export::XlsxBuilder/PdfBuilder) - o
# teto de 40MB por anexo (TicketAttachment::MAXIMUM_FILE_SIZE) ja mantem um
# ticket inteiro de anexos num tamanho que cabe sem precisar de streaming.
class Tickets::Attachments::ZipBuilder
  pattr_initialize [:ticket!]

  def render
    buffer = Zip::OutputStream.write_buffer do |zip|
      attachments.each do |attachment|
        zip.put_next_entry(entry_name_for(attachment))
        # `blob.open` streams to a tempfile instead of loading the whole file
        # into memory, which matters at the 40 MB attachment limit.
        attachment.file.blob.open { |file| IO.copy_stream(file, zip) }
      end
    end
    buffer.rewind
    buffer.read
  end

  private

  def attachments
    ticket.ticket_attachments.includes(file_attachment: :blob)
  end

  # Dois anexos com o mesmo nome (comum - "print.png" de dois prints
  # diferentes) nao podem virar a mesma entrada no zip, ou um sobrescreve o
  # outro silenciosamente. So' o repetido ganha sufixo, pra nao desfigurar o
  # nome do caso comum (sem duplicata).
  def entry_name_for(attachment)
    name = attachment.file.filename.to_s
    return name if seen_names.add?(name)

    ext = File.extname(name)
    base = File.basename(name, ext)
    "#{base}-#{attachment.id}#{ext}"
  end

  def seen_names
    @seen_names ||= Set.new
  end
end
