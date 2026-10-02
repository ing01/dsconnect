require 'zip'

# Le um arquivo .docx e devolve a lista (unica, ordenada) de tokens
# `[[assim]]` encontrados no texto. Agrupa por paragrafo antes de procurar o
# token porque o Word costuma quebrar um mesmo texto em varios `<w:t>` (runs)
# por causa de formatacao - sem agrupar, um token poderia ficar partido entre
# dois runs e nao bater com o regex.
class Crm::Contracts::TokenExtractorService
  TOKEN_REGEX = /\[\[([a-zA-Z0-9_]+)\]\]/
  TARGET_ENTRY_REGEX = %r{\Aword/(document|header\d*|footer\d*)\.xml\z}
  WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

  def initialize(file_path)
    @file_path = file_path
  end

  def perform
    tokens = Set.new

    Zip::File.open(@file_path) do |zip|
      zip.each do |entry|
        next unless entry.name.match?(TARGET_ENTRY_REGEX)

        collect_tokens(entry.get_input_stream.read, tokens)
      end
    end

    tokens.to_a.sort
  rescue Zip::Error, Nokogiri::XML::SyntaxError => e
    Rails.logger.warn "Crm::Contracts::TokenExtractorService falhou para #{@file_path}: #{e.message}"
    []
  end

  private

  def collect_tokens(xml_content, tokens)
    doc = Nokogiri::XML(xml_content)
    doc.xpath('//xmlns:p', 'xmlns' => WORD_NS).each do |paragraph|
      text = paragraph.xpath('.//xmlns:t', 'xmlns' => WORD_NS).map(&:text).join
      text.scan(TOKEN_REGEX) { tokens << Regexp.last_match(1) }
    end
  end
end
