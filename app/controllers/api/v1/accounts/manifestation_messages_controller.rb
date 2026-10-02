# As respostas e as anotacoes internas de uma manifestacao, do lado da equipe.
#
# Aqui `visibility` VEM do pedido - e a escolha entre responder ao cliente e
# anotar para a equipe. E a unica porta onde essa escolha existe: o controller do
# cliente fixa `public_reply`.
class Api::V1::Accounts::ManifestationMessagesController < Api::V1::Accounts::BaseController
  before_action :fetch_manifestation
  before_action :check_authorization

  def create
    return render_empty_message if params[:body].to_s.strip.blank?

    ActiveRecord::Base.transaction do
      @message = build_message
      @message.save!
      log_message!
      mark_awaiting_customer!
    end

    render 'show', status: :created
  end

  private

  def fetch_manifestation
    @manifestation = Current.account.manifestations.find(params[:manifestation_id])
  end

  # A permissao e da MANIFESTACAO: quem pode trabalhar nela pode responder e
  # anotar.
  def check_authorization(_model = nil)
    authorize(@manifestation, :update?)
  end

  def build_message
    @manifestation.manifestation_messages.new(
      account_id: @manifestation.account_id,
      user: Current.user,
      visibility: internal_note? ? :internal_note : :public_reply,
      body: params[:body].to_s.strip
    )
  end

  # Anotacao interna so quando pedida explicitamente. O padrao e a resposta
  # PUBLICA porque e a acao mais comum - mas o default errado aqui vazaria uma
  # nota, entao a leitura e estrita: so `true` conta.
  def internal_note?
    ActiveModel::Type::Boolean.new.cast(params[:internal]) == true
  end

  def log_message!
    @manifestation.manifestation_activities.create!(
      user: Current.user,
      activity_type: internal_note? ? :internal_note_added : :replied
    )
  end

  # Respondeu ao cliente e pediu para aguardar: quem responde normalmente espera
  # retorno. So acontece quando a tela manda `awaiting_customer`, para nao
  # decidir pelo agente.
  def mark_awaiting_customer!
    return if internal_note?
    return unless ActiveModel::Type::Boolean.new.cast(params[:awaiting_customer])
    return if @manifestation.status_awaiting_customer?

    anterior = @manifestation.status
    @manifestation.update!(status: :awaiting_customer)
    @manifestation.manifestation_activities.create!(
      user: Current.user, activity_type: :status_changed,
      previous_value: anterior, new_value: @manifestation.status
    )
  end

  def render_empty_message
    render json: { error: I18n.t('manifestations.message.empty'), code: 'body_required' },
           status: :unprocessable_entity
  end
end
