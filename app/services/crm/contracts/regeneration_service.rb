require 'tmpdir'

# Regenera o PDF/DOCX de um Crm::GeneratedContract JA' existente, atualizando
# so' os tokens que podem ter mudado desde a geracao original (identidade do
# cliente + representante - ver Crm::ContractTokenMapper) e preservando tudo
# que foi digitado a mao na geracao (licenca, implantacao etc.). A versao
# anterior (dados + arquivos) e' arquivada numa Crm::GeneratedContractRevision
# antes de sobrescrever, para nunca perder o contrato com o representante
# antigo.
class Crm::Contracts::RegenerationService
  pattr_initialize [:contract!, :reason]

  def perform
    ActiveRecord::Base.transaction(requires_new: true) do
      archive_current_version!
      merged_data = contract.data.merge(fresh_overlay_tokens)
      regenerate_files!(merged_data)
      contract.update!(data: merged_data)
    end
    contract
  end

  private

  attr_reader :contract

  # So' os tokens que uma troca de representante pode de fato mudar - nunca
  # o resto do `data` (licenca, implantacao, valores) que so existe porque
  # alguem digitou na tela na geracao original.
  def fresh_overlay_tokens
    mapper_tokens = Crm::ContractTokenMapper.new(client: contract.client, sale: contract.sale).to_h
    keys = Crm::ContractTokenMapper::LOCKED_CLIENT_TOKEN_KEYS + Crm::ContractTokenMapper::REPRESENTATIVE_TOKEN_KEYS
    mapper_tokens.slice(*keys)
  end

  # Baixa os arquivos ATUAIS do contrato e sobe como blobs NOVOS na revisao -
  # de proposito nao reaproveita o blob do contrato diretamente, para nunca
  # correr risco do Active Storage purgar um blob compartilhado quando o
  # contrato trocar de anexo mais abaixo.
  def archive_current_version!
    return unless contract.pdf.attached? || contract.docx.attached?

    revision = contract.revisions.create!(account: contract.account, data: contract.data, reason: reason)
    archive_attachment!(revision.pdf, contract.pdf)
    archive_attachment!(revision.docx, contract.docx)
  end

  def archive_attachment!(target, source)
    return unless source.attached?

    target.attach(io: StringIO.new(source.download), filename: source.filename.to_s, content_type: source.content_type)
  end

  def regenerate_files!(merged_data)
    Dir.mktmpdir do |dir|
      filled_path = fill_template(dir, merged_data)
      pdf_path = Crm::Contracts::PdfConversion.convert!(filled_path, dir)
      attach_generated_files!(pdf_path, filled_path)
    end
  end

  def fill_template(dir, merged_data)
    source_path = File.join(dir, 'modelo.docx')
    contract.template.file.blob.open { |tmp_file| FileUtils.cp(tmp_file.path, source_path) }

    filled_path = File.join(dir, 'preenchido.docx')
    Crm::Contracts::DocxFillerService.new(source_path, merged_data).perform(filled_path)
    filled_path
  end

  def attach_generated_files!(pdf_path, filled_path)
    base_filename = "#{contract.template.name.parameterize}-#{contract.client.name.parameterize}"

    contract.pdf.attach(io: File.open(pdf_path), filename: "#{base_filename}.pdf", content_type: 'application/pdf')
    contract.docx.attach(
      io: File.open(filled_path), filename: "#{base_filename}.docx",
      content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    )
  end
end
