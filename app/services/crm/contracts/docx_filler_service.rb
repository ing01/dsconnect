require 'zip'
require 'fileutils'

# Preenche um .docx substituindo `[[token]]` pelo valor correspondente em
# `data`. Mesma logica de agrupar por paragrafo do TokenExtractorService: ao
# achar `[[` no texto completo de um paragrafo, escreve o texto substituido
# inteiro no primeiro `<w:t>` do paragrafo e esvazia os demais - perde
# formatacao fina (negrito no meio da frase), mas garante que o token seja
# substituido mesmo quando o Word o quebrou em varios runs.
class Crm::Contracts::DocxFillerService
  TOKEN_REGEX = /\[\[([a-zA-Z0-9_]+)\]\]/
  TARGET_ENTRY_REGEX = %r{\Aword/(document|header\d*|footer\d*)\.xml\z}
  WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

  def initialize(source_path, data)
    @source_path = source_path
    @data = data.stringify_keys
  end

  def perform(output_path)
    FileUtils.cp(@source_path, output_path)

    entries_xml = {}
    Zip::File.open(output_path) do |zip|
      zip.each do |entry|
        next unless entry.name.match?(TARGET_ENTRY_REGEX)

        entries_xml[entry.name] = fill_entry(entry.get_input_stream.read)
      end
    end

    Zip::File.open(output_path) do |zip|
      entries_xml.each do |name, xml|
        zip.get_output_stream(name) { |out| out.write(xml) }
      end
    end

    output_path
  end

  private

  def fill_entry(xml_content)
    doc = Nokogiri::XML(xml_content)
    doc.xpath('//xmlns:p', 'xmlns' => WORD_NS).each { |paragraph| fill_paragraph(paragraph) }
    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  def fill_paragraph(paragraph)
    text_nodes = paragraph.xpath('.//xmlns:t', 'xmlns' => WORD_NS)
    return if text_nodes.empty?

    full_text = text_nodes.map(&:text).join
    return unless full_text.include?('[[')

    # Campo vazio (ou token que nem apareceu no formulario) fica EM BRANCO -
    # nunca mantem o `[[nome_do_token]]` solto no contrato gerado.
    filled_text = full_text.gsub(TOKEN_REGEX) { @data[$1].to_s }

    first_node = text_nodes.first
    first_node.content = filled_text
    first_node['xml:space'] = 'preserve'
    text_nodes[1..].each { |node| node.content = '' }
  end
end
