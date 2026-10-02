require 'open3'
require 'tmpdir'

# Gera o PDF de um contrato: preenche o .docx do modelo com os dados do
# cliente/venda + o que foi digitado na tela, e converte para PDF via
# LibreOffice (`soffice --headless --convert-to pdf`), que precisa estar
# instalado no servidor. Sem LibreOffice instalado, levanta ConversionError
# com uma mensagem clara em vez de travar silenciosamente.
class Crm::Contracts::GenerationService
  class ConversionError < StandardError; end

  def initialize(template:, client:, sale: nil, data: {})
    @template = template
    @client = client
    @sale = sale
    @data = Crm::ContractTokenMapper.new(client: client, sale: sale).to_h.merge(data.to_h.stringify_keys)
  end

  def perform
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, 'modelo.docx')
      File.binwrite(source_path, @template.file.download)

      filled_path = File.join(dir, 'preenchido.docx')
      Crm::Contracts::DocxFillerService.new(source_path, @data).perform(filled_path)

      pdf_path = convert_to_pdf(filled_path, dir)

      contract = Crm::GeneratedContract.new(
        account_id: @template.account_id,
        template: @template,
        client: @client,
        sale: @sale,
        data: @data
      )
      contract.pdf.attach(
        io: File.open(pdf_path),
        filename: "#{@template.name.parameterize}-#{@client.name.parameterize}.pdf",
        content_type: 'application/pdf'
      )
      contract.save!
      contract
    end
  end

  private

  def convert_to_pdf(docx_path, dir)
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
