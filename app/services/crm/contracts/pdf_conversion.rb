require 'open3'

# Converte um .docx em PDF via LibreOffice (`soffice --headless --convert-to
# pdf`), que precisa estar instalado no servidor. Extraido de
# Crm::Contracts::GenerationService para ser reaproveitado tambem pelo
# Crm::Contracts::RegenerationService, sem duplicar a chamada ao Open3 nem o
# tratamento de erro.
module Crm::Contracts::PdfConversion
  class ConversionError < StandardError; end

  def self.convert!(docx_path, dir)
    _stdout, stderr, status = Open3.capture3('soffice', '--headless', '--convert-to', 'pdf', '--outdir', dir, docx_path)
    unless status.success?
      raise ConversionError, (stderr.presence || 'Falha ao converter para PDF - o LibreOffice (soffice) esta instalado no servidor?')
    end

    pdf_path = docx_path.sub(/\.docx\z/, '.pdf')
    raise ConversionError, 'O LibreOffice nao gerou o PDF esperado' unless File.exist?(pdf_path)

    pdf_path
  rescue Errno::ENOENT
    raise ConversionError, 'O LibreOffice (comando "soffice") nao foi encontrado no servidor - precisa instalar (sudo apt install -y libreoffice).'
  end
end
