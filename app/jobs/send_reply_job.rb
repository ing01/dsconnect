class SendReplyJob < ApplicationJob
  queue_as :high

  # Ate quantas vezes esperar a vez antes de desistir e despachar assim mesmo -
  # rede de seguranca caso a mensagem mais antiga trave por algum motivo (job
  # que nunca chegou a rodar, por exemplo). 20 tentativas de 1s = ate ~20s de
  # espera, bem acima do tempo normal de uma chamada de API.
  MAX_ORDER_WAIT_ATTEMPTS = 20
  ORDER_WAIT_DELAY = 1.second

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  def perform(message_id, attempt = 1)
    message = Message.find_by(id: message_id)
    return if message.blank?

    if attempt <= MAX_ORDER_WAIT_ATTEMPTS && awaiting_earlier_message?(message)
      self.class.set(wait: ORDER_WAIT_DELAY).perform_later(message_id, attempt + 1)
      return
    end

    dispatch(message)
  end

  private

  def dispatch(message)
    channel_name = message.conversation.inbox.channel.class.to_s

    return send_on_facebook_page(message) if channel_name == 'Channel::FacebookPage'

    service_class = CHANNEL_SERVICES[channel_name]
    return unless service_class

    service_class.new(message: message).perform
  end

  # Garante que as mensagens de uma conversa cheguem ao provedor (WhatsApp,
  # etc.) na mesma ordem em que foram criadas. Sem isso, duas mensagens
  # disparadas em sequencia rapida (por exemplo, duas etapas seguidas do fluxo
  # automatico de triagem, sem esperar resposta entre uma e outra) rodam em
  # jobs concorrentes que competem por rede - quem responde mais rapido chega
  # primeiro no WhatsApp do cliente, mesmo que tenha sido criada depois. O
  # Chatwoot sempre exibe pela ordem de CRIACAO, entao a tela do atendente
  # parece certa mesmo quando a entrega saiu errada (relatado: "chega pra mim
  # errado, mas no sistema ta na ordem correta").
  #
  # So se aplica a mensagem que de fato vai ser despachada (outgoing/template,
  # nao privada) - mensagem incoming ou nota interna nunca passa por
  # `channel.send_message`, entao nao precisa esperar vez nem bloqueia
  # ninguem.
  def awaiting_earlier_message?(message)
    return false unless dispatchable?(message)

    earlier_undispatched_siblings(message).exists?
  end

  def dispatchable?(message)
    (message.outgoing? || message.template?) && !message.private?
  end

  # `source_id` so e preenchido depois que `channel.send_message`/`send_template`
  # de fato responde com o id do provedor - e o sinal confiavel de "ja foi
  # mandada de verdade", diferente de `status`, que ja nasce como `sent` por
  # otimismo antes de qualquer envio real. Mensagem que falhou nao pode travar
  # as de tras indefinidamente, por isso fica de fora do bloqueio.
  def earlier_undispatched_siblings(message)
    message.conversation.messages
           .where(message_type: %i[outgoing template], private: false, source_id: nil)
           .where.not(id: message.id)
           .where.not(status: :failed)
           .where('created_at < :ts OR (created_at = :ts AND id < :id)', ts: message.created_at, id: message.id)
  end

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end
end
