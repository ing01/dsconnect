require 'tmpdir'

# Gera o PDF de um contrato: preenche o .docx do modelo com os dados do
# cliente/venda + o que foi digitado na tela, e converte para PDF via
# Crm::Contracts::PdfConversion (LibreOffice).
class Crm::Contracts::GenerationService
  # Mesma classe de erro de PdfConversion, com o nome antigo preservado -
  # quem ja' faz `rescue Crm::Contracts::GenerationService::ConversionError`
  # (ver generated_contracts_controller.rb) continua funcionando sem mudanca.
  ConversionError = Crm::Contracts::PdfConversion::ConversionError

  def initialize(template:, client:, sale: nil, data: {})
    @template = template
    @client = client
    @sale = sale

    # Os tokens de identidade do cliente (razao social, CNPJ, nome fantasia,
    # e-mail, telefone) SEMPRE vem do cadastro - um valor digitado a mao na
    # tela de geracao (`data`) nunca pode sobrescreve-los, por isso o merge
    # dos tokens do cadastro vem de novo, por cima, so' com essa fatia.
    mapper_tokens = Crm::ContractTokenMapper.new(client: client, sale: sale).to_h
    @data = mapper_tokens.merge(data.to_h.stringify_keys)
                         .merge(mapper_tokens.slice(*Crm::ContractTokenMapper::LOCKED_CLIENT_TOKEN_KEYS))
  end

  def perform
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, 'modelo.docx')
      File.binwrite(source_path, @template.file.download)

      filled_path = File.join(dir, 'preenchido.docx')
      Crm::Contracts::DocxFillerService.new(source_path, @data).perform(filled_path)

      pdf_path = Crm::Contracts::PdfConversion.convert!(filled_path, dir)

      base_filename = "#{@template.name.parameterize}-#{@client.name.parameterize}"

      contract = Crm::GeneratedContract.new(
        account_id: @template.account_id,
        template: @template,
        client: @client,
        sale: @sale,
        data: @data
      )
      contract.pdf.attach(
        io: File.open(pdf_path),
        filename: "#{base_filename}.pdf",
        content_type: 'application/pdf'
      )
      contract.docx.attach(
        io: File.open(filled_path),
        filename: "#{base_filename}.docx",
        content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      contract.save!
      contract
    end
  end
end
