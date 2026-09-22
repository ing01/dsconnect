# Portao de bloqueio do fluxo de triagem: roda antes de qualquer execucao
# comecar, e nao como uma etapa configuravel - assim nenhuma automacao mal
# montada consegue "esquecer" de checar bloqueio.
#
# So olha o que ja da para saber sem ter identificado a Empresa ainda (o
# contato da conversa, e a Empresa primaria dele, se houver). Uma Empresa
# escolhida no meio da conversa via CNPJ e checada depois, pela etapa
# `check_company_blocked`.
class AutomationRules::Flow::BlockGateService
  def initialize(conversation:)
    @conversation = conversation
  end

  def allowed?
    return false if contact.blank?
    return false if contact.blocked?
    return false if whatsapp_inbox? && !whatsapp_flow_enabled?
    return false if whatsapp_inbox? && !whatsapp_test_mode_allowed?
    return false if primary_company&.blocked?

    true
  end

  private

  attr_reader :conversation

  def contact
    conversation.contact
  end

  def primary_company
    contact.company
  end

  def whatsapp_inbox?
    conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def whatsapp_test_mode_allowed?
    conversation.account.whatsapp_automation_allowed_for?(contact.phone_number)
  end

  def whatsapp_flow_enabled?
    value = conversation.account.helpdesk_whatsapp_flow_enabled
    value.nil? || ActiveModel::Type::Boolean.new.cast(value)
  end
end
