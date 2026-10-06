require 'zip'

# Monta um .docx minimo (so com o `word/document.xml` que o
# Crm::Contracts::DocxFillerService realmente le) para testar o pipeline de
# geracao/regeneracao de contrato sem precisar de um arquivo .docx de
# verdade.
module CrmContractFixtures
  WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'.freeze

  def build_minimal_docx(paragraph_text)
    path = File.join(Dir.tmpdir, "modelo-#{SecureRandom.hex(4)}.docx")
    document_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{WORD_NS}">
        <w:body>
          <w:p>
            <w:r><w:t>#{paragraph_text}</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
    XML

    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream('word/document.xml') { |out| out.write(document_xml) }
    end

    path
  end

  # Substitui a conversao real por LibreOffice (que os testes nao devem
  # depender de ter instalado) - so' escreve um arquivo .pdf qualquer no
  # lugar certo, o suficiente para o resto do pipeline (attach, etc.)
  # continuar.
  def stub_pdf_conversion!
    allow(Crm::Contracts::PdfConversion).to receive(:convert!) do |docx_path, _dir|
      pdf_path = docx_path.sub(/\.docx\z/, '.pdf')
      File.write(pdf_path, '%PDF-1.4 fake')
      pdf_path
    end
  end
end

RSpec.configure do |config|
  config.include CrmContractFixtures
end
