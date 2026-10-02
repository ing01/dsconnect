require 'rails_helper'

# As notificacoes do chat do Portal do Cliente.
#
# O que se valida aqui e a ENTREGA: quando a equipe escreve, o Contato precisa
# ser avisado mesmo estando fora da tela de chat - e e esse aviso que sai por
# push de navegador. O e-mail e o reforco da primeira mensagem da sessao.
#
# Tambem se valida o que NAO deve notificar: nota privada, mensagem do proprio
# cliente e mensagem de qualquer outro canal (WhatsApp, e-mail) nao tem Contato
# nenhum esperando aviso de navegador do Portal.
describe ClientPortalChatListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:agente) { create(:user, account: account) }

  # A caixa do Portal e marcada em `additional_attributes`, e e essa marca que o
  # listener usa para se reconhecer - nao o nome, que a equipe pode editar.
  let!(:portal_inbox) { Inboxes::EnsureClientPortalInboxService.new(account: account).perform }

  let!(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br')
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  let!(:conversa) do
    create(:conversation, account: account, inbox: portal_inbox, contact: cliente)
  end

  # Sem inscricao de push nao ha para onde mandar. Uma por aparelho: o cliente
  # pode ter ligado o aviso no celular e no computador.
  def inscrever(endpoint: 'https://push.exemplo/abc')
    ClientPushSubscription.create!(
      account: account, contact: cliente,
      subscription_attributes: { 'endpoint' => endpoint, 'p256dh' => 'chave', 'auth' => 'auth' }
    )
  end

  def mensagem_da_equipe(conteudo: 'Bom dia, já verifiquei aqui.', private_note: false)
    create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                     message_type: :outgoing, sender: agente, private: private_note,
                     content: conteudo)
  end

  def disparar(message)
    listener.message_created(
      Events::Base.new('message.created', Time.zone.now, message: message, account: account)
    )
  end

  describe 'a equipe responde no chat do Portal' do
    before { inscrever }

    it 'sends a browser push to the contact' do
      expect(WebPush).to receive(:payload_send).once

      disparar(mensagem_da_equipe)
    end

    # O corpo do push e o texto da mensagem: e por ele que a pessoa decide se
    # vale abrir agora. Um push so com o titulo nao informa nada.
    it 'carries the message text in the push body' do
      allow(WebPush).to receive(:payload_send) do |args|
        corpo = JSON.parse(args[:message])
        expect(corpo['body']).to eq('Bom dia, já verifiquei aqui.')
        expect(corpo['url']).to eq('/app/client/chat')
      end

      disparar(mensagem_da_equipe)
    end

    # A etiqueta por conversa e o que faz a segunda mensagem SUBSTITUIR o aviso
    # da primeira, em vez de empilhar um aviso por linha dita.
    it 'tags the push by conversation, so a new message replaces the previous notice' do
      allow(WebPush).to receive(:payload_send) do |args|
        expect(JSON.parse(args[:message])['tag']).to eq("client_chat_#{conversa.id}")
      end

      disparar(mensagem_da_equipe)
    end

    it 'reaches every device the contact enabled' do
      inscrever(endpoint: 'https://push.exemplo/segundo-aparelho')

      expect(WebPush).to receive(:payload_send).twice

      disparar(mensagem_da_equipe)
    end

    # TODA mensagem avisa - nao so a primeira da sessao. O cliente quer saber
    # sempre que chegou algo novo.
    it 'pushes on every message, not just the first' do
      expect(WebPush).to receive(:payload_send).twice

      disparar(mensagem_da_equipe(conteudo: 'Primeira'))
      disparar(mensagem_da_equipe(conteudo: 'Segunda'))
    end

    # Mensagem so com anexo nao tem texto; o aviso precisa dizer alguma coisa.
    it 'falls back to a generic body when the message has no text' do
      allow(WebPush).to receive(:payload_send) do |args|
        expect(JSON.parse(args[:message])['body']).to be_present
      end

      disparar(mensagem_da_equipe(conteudo: ''))
    end
  end

  describe 'o e-mail de reforco' do
    before { inscrever }

    it 'sends an e-mail on the first message of the session' do
      allow(WebPush).to receive(:payload_send)

      expect { disparar(mensagem_da_equipe) }
        .to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    # Um e-mail por linha de conversa seria spam - o push ja avisa em tempo real.
    it 'does not send another e-mail for the following messages' do
      allow(WebPush).to receive(:payload_send)
      disparar(mensagem_da_equipe(conteudo: 'Primeira'))

      expect { disparar(mensagem_da_equipe(conteudo: 'Segunda')) }
        .not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe 'o que NAO deve avisar o cliente' do
    before { inscrever }

    # Nota privada e conversa interna da equipe: mandar push dela ao cliente
    # seria vazamento, nao notificacao.
    it 'never pushes a private note' do
      expect(WebPush).not_to receive(:payload_send)

      disparar(mensagem_da_equipe(private_note: true))
    end

    # A mensagem do proprio cliente nao e novidade para quem a escreveu.
    it 'does not push the contact own message back to them' do
      expect(WebPush).not_to receive(:payload_send)

      entrada = create(:message, account: account, inbox: portal_inbox, conversation: conversa,
                                 message_type: :incoming, content: 'Minha dúvida')
      disparar(entrada)
    end

    # Outro canal nao tem Contato esperando aviso de navegador do Portal.
    it 'ignores a message from another channel' do
      outra_inbox = create(:inbox, account: account)
      outra_conversa = create(:conversation, account: account, inbox: outra_inbox, contact: cliente)

      expect(WebPush).not_to receive(:payload_send)

      disparar(create(:message, account: account, inbox: outra_inbox, conversation: outra_conversa,
                                message_type: :outgoing, sender: agente, content: 'Oi'))
    end
  end

  describe 'quando nao ha a quem avisar' do
    it 'does nothing when the contact never enabled notifications' do
      expect(WebPush).not_to receive(:payload_send)

      allow(ClientChatMailer).to receive(:new_message)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: true))
      disparar(mensagem_da_equipe)
    end

    # Inscricao vencida (navegador reinstalado, permissao revogada) e removida na
    # hora: insistir nela a cada mensagem gastaria uma requisicao por aviso, para
    # sempre.
    it 'drops a subscription the push service has rejected' do
      inscricao = inscrever
      # `WebPush::ResponseError#initialize` le `response.body` para montar a
      # mensagem - por isso a resposta e um duble, e nao `nil`.
      recusa = WebPush::ExpiredSubscription.new(
        instance_double(Net::HTTPGone, body: 'gone'), 'push.exemplo'
      )
      allow(WebPush).to receive(:payload_send).and_raise(recusa)
      allow(ClientChatMailer).to receive(:new_message)
        .and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: true))

      disparar(mensagem_da_equipe)

      expect(ClientPushSubscription.exists?(inscricao.id)).to be(false)
    end
  end
end
