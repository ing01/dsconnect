# Uma mensagem do cliente no chat com a equipe - texto, audio gravado e/ou
# anexos, na MESMA mensagem.
#
# Usa o `Messages::MessageBuilder` (o MESMO builder que o reply box do painel
# usa) em vez de `conversation.messages.create!` direto: e' ele que sabe
# anexar arquivos (`params[:attachments]`), detectar que um deles e' audio
# pelo `content_type` e marcar `is_voice_message`, sem reinventar nada disso
# aqui. `message_type: 'incoming'` so e' aceito pelo builder em Inbox
# `Channel::Api` (valida em `MessageBuilder#message_type`) - exatamente o
# canal do chat do Portal.
class Api::V1::Client::ChatMessagesController < Api::V1::Client::BaseController
  before_action :fetch_conversation, only: [:create]
  before_action :fetch_csat_message, only: [:update]

  def create
    return render_empty_message if content_blank? && uploaded_files.empty?

    @message = Messages::MessageBuilder.new(nil, @conversation, message_params).perform

    render 'api/v1/client/chats/message', status: :created
  end

  # A resposta da pesquisa de satisfacao (nota + comentario). O MESMO
  # mecanismo do Widget (`Api::V1::Widget::MessagesController#update`):
  # atualizar `content_attributes.submitted_values` dispara `message_updated`,
  # e e' o `CsatSurveyListener` (ja registrado, generico) que grava a
  # `CsatSurveyResponse` a partir dai - nada disso e' escrito aqui.
  def update
    @message.update!(csat_submission_params)
    render 'api/v1/client/chats/message'
  end

  private

  # A MESMA regra de `show` do chat: sessao anterior resolvida vira uma
  # conversa NOVA, transparente para quem esta escrevendo. A tela do cliente
  # compara `conversation_id`/`pubsub_token` da resposta com o que tinha
  # assinado e se resubscreve sozinha quando muda - por isso a mensagem
  # sempre entra na conversa certa mesmo que a aba tivesse ficado aberta
  # desde antes do atendente resolver a sessao anterior.
  def fetch_conversation
    @conversation = ::Client::ChatConversationResolver.new(account: Current.account, contact: current_contact).perform
  end

  # A pesquisa chega numa conversa que acabou de ser RESOLVIDA - o resolver
  # acima criaria uma sessao nova por engano se fosse usado aqui. A busca e'
  # direta: qualquer conversa do Inbox do Portal que pertenca a este contato,
  # aberta ou nao.
  def fetch_csat_message
    inbox = ::Inboxes::EnsureClientPortalInboxService.find_existing(Current.account)
    @message = Message.joins(:conversation)
                       .where(conversations: { inbox_id: inbox&.id, contact_id: current_contact.id })
                       .where(content_type: :input_csat)
                       .find(params[:id])
  end

  def content_blank?
    params[:content].to_s.strip.blank?
  end

  def uploaded_files
    Array(params[:attachments]).reject(&:blank?)
  end

  def message_params
    {
      content: params[:content].to_s.strip.presence,
      message_type: 'incoming',
      attachments: uploaded_files,
      is_voice_message: params[:is_voice_message]
    }
  end

  # `submitted_values` e' um accessor do `store :content_attributes` do
  # Message - grava so essa chave dentro do jsonb, sem apagar `display_type`
  # (gravado na criacao da mensagem) como um `content_attributes: {...}`
  # direto faria.
  def csat_submission_params
    {
      submitted_values: {
        csat_survey_response: {
          rating: params[:rating],
          feedback_message: params[:feedback_message]
        }
      }
    }
  end

  def render_empty_message
    render json: { error: I18n.t('client_area.chat.empty'), code: 'content_required' }, status: :unprocessable_entity
  end
end
