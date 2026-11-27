# Entrega o resumo da IA para a conversa: o guardado, se nada mudou, ou um novo.
class CustomerBriefing::SummaryService
  # Mudar o prompt ou o formato da resposta pede um numero novo aqui, para os
  # textos guardados serem refeitos.
  PROMPT_VERSION = 1
  RETENTION = 30.days
  # Erros que ja chegam com uma frase pensada para quem le (IA desligada, sem
  # chave, sem credito). Os demais sao mensagens tecnicas do provedor.
  EXPLAINED_ERROR_CODES = [401, 403, 429].freeze

  pattr_initialize [:conversation!, :user!, { company_id: nil, force: false }]

  def perform
    return { summary: nil, empty: true } if material.blank?

    saved = saved_summary
    return payload(saved, cached: true) if saved && !force

    result = Captain::CustomerBriefingService.new(account: account, material: material).perform
    return { error: error_message(result) } if result[:error]

    payload(save(result[:message]), cached: false)
  end

  private

  delegate :account, :contact, to: :conversation

  def sources
    @sources ||= CustomerBriefing::Sources.new(conversation: conversation, user: user, company_id: company_id)
  end

  def material
    @material ||= CustomerBriefing::MaterialBuilder.new(sources: sources).perform
  end

  def fingerprint
    @fingerprint ||= Digest::SHA256.hexdigest([PROMPT_VERSION, contact.id, sources.company&.id, material].join("\n"))
  end

  def saved_summary
    CustomerBriefingSummary.find_by(account_id: account.id, fingerprint: fingerprint)
  end

  def save(content)
    record = saved_summary || CustomerBriefingSummary.new(account: account, fingerprint: fingerprint)
    record.update!(contact: contact, company: sources.company, content: content, updated_at: Time.current)
    discard_old
    record
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Duas pessoas abriram ao mesmo tempo: vale o que foi guardado primeiro.
    saved_summary || raise
  end

  def discard_old
    CustomerBriefingSummary.where(contact_id: contact.id, updated_at: ...RETENTION.ago).delete_all
  end

  def payload(record, cached:)
    { summary: record.content, generated_at: record.updated_at.to_i, cached: cached }
  end

  def error_message(result)
    return result[:error] if EXPLAINED_ERROR_CODES.include?(result[:error_code])

    Rails.logger.warn "[CustomerBriefing] account=#{account.id} #{result[:error]}"
    I18n.t('captain.customer_briefing.failed')
  end
end
