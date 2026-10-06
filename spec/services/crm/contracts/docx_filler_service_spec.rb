require 'rails_helper'
require 'zip'

RSpec.describe Crm::Contracts::DocxFillerService do
  let(:word_ns) { 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }
  let(:output_path) { temp_docx_path('preenchido') }

  after do
    FileUtils.rm_f(output_path)
  end

  def temp_docx_path(prefix)
    File.join(Dir.tmpdir, "#{prefix}-#{SecureRandom.hex(4)}.docx")
  end

  # Um .docx minimo, so com o `word/document.xml` que o servico realmente le -
  # o suficiente pro teste, sem precisar de um arquivo .docx de verdade.
  def build_docx(paragraph_text)
    path = temp_docx_path('modelo')
    document_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{word_ns}">
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

  def preencher(source, data)
    described_class.new(source, data).perform(output_path)
  ensure
    FileUtils.rm_f(source)
  end

  def filled_paragraph_text
    Zip::File.open(output_path) do |zip|
      xml = Nokogiri::XML(zip.read('word/document.xml'))
      xml.xpath('//xmlns:t', 'xmlns' => word_ns).map(&:text).join
    end
  end

  it 'substitui um token presente nos dados' do
    preencher(build_docx('Razao social: [[cliente_razao_social]]'), { 'cliente_razao_social' => 'Duesoft' })

    expect(filled_paragraph_text).to eq('Razao social: Duesoft')
  end

  # O PONTO CENTRAL do bug relatado: um campo vazio (ou nem enviado do
  # formulario) tem que desaparecer do contrato, nunca deixar `[[token]]`
  # solto no texto - era exatamente isso que deixava o PDF "zoado".
  it 'deixa em branco um token ausente dos dados, em vez de manter [[token]] literal' do
    preencher(build_docx('CEP: [[cliente_cep]] - Fim'), {})

    expect(filled_paragraph_text).to eq('CEP:  - Fim')
    expect(filled_paragraph_text).not_to include('[[')
  end

  it 'deixa em branco um token com valor nil' do
    preencher(build_docx('IE: [[cliente_inscricao_estadual]]'), { 'cliente_inscricao_estadual' => nil })

    expect(filled_paragraph_text).to eq('IE: ')
  end

  it 'mistura tokens preenchidos e ausentes no mesmo paragrafo' do
    preencher(build_docx('[[cliente_razao_social]] - CNPJ [[cliente_cnpj]]'), { 'cliente_razao_social' => 'Duesoft' })

    expect(filled_paragraph_text).to eq('Duesoft - CNPJ ')
  end
end
