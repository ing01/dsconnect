# A resposta do cliente dentro de uma manifestacao.
#
# Entra na MESMA conversa que a equipe le, com `visibility: public_reply` - nao
# ha thread separada. O cliente nao tem como criar nota interna: `visibility` nao
# e lido dos parametros, e sim fixado aqui.
class Api::V1::Client::ManifestationMessagesController < Api::V1::Client::BaseController
  before_action :fetch_manifestation

  def create
    return render_empty_message if params[:body].to_s.strip.blank?
    return render_finished if @manifestation.finished?

    ActiveRecord::Base.transaction do
      @message = build_message
      @message.save!
      attach_uploaded_files!
      log_reply!
      answer_the_team!
    end

    render 'api/v1/client/manifestation_messages/show', status: :created
  end

  private

  # `visible_manifestations` e a fronteira: responder numa manifestacao de outra
  # empresa nao encontra o registro, e vira 404.
  def fetch_manifestation
    @manifestation = current_contact.visible_manifestations.find(params[:manifestation_id])
  end

  def build_message
    @manifestation.manifestation_messages.new(
      account_id: @manifestation.account_id,
      contact: current_contact,
      # Fixado, nao lido do pedido: o cliente so escreve em publico.
      visibility: :public_reply,
      body: params[:body].to_s.strip
    )
  end

  def attach_uploaded_files!
    Array(params[:attachments]).reject(&:blank?).each do |arquivo|
      anexo = @manifestation.manifestation_attachments.new(
        account_id: @manifestation.account_id,
        contact: current_contact
      )
      anexo.file.attach(arquivo)
      anexo.save!
    end
  end

  def log_reply!
    @manifestation.manifestation_activities.create!(
      contact: current_contact,
      activity_type: :client_replied
    )
  end

  # Estava "Aguardando retorno do cliente" e o retorno chegou: volta para a fila
  # da equipe sozinho. Sem isso a manifestacao ficaria parada esperando alguem
  # notar que a resposta ja veio.
  def answer_the_team!
    return unless @manifestation.status_awaiting_customer?

    anterior = @manifestation.status
    @manifestation.update!(status: :in_progress)
    @manifestation.manifestation_activities.create!(
      contact: current_contact,
      activity_type: :status_changed,
      previous_value: anterior,
      new_value: @manifestation.status
    )
  end

  def render_empty_message
    render json: { error: I18n.t('manifestations.message.empty'), code: 'body_required' },
           status: :unprocessable_entity
  end

  def render_finished
    render json: { error: I18n.t('manifestations.message.finished'), code: 'finished' },
           status: :unprocessable_entity
  end
end
