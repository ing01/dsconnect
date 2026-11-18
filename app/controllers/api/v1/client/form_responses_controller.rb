# O cliente logado envia as respostas de um formulario publicado. A resposta fica guardada na lista
# de respostas do formulario (sem chamado), com o contato que respondeu.
class Api::V1::Client::FormResponsesController < Api::V1::Client::BaseController
  def create
    form = current_contact.account.forms.published.find(params[:form_id])
    Forms::SubmitService.new(
      form: form, source: 'client', contact: current_contact,
      answers: params[:answers] || {}, files: params[:files] || {}
    ).perform
    render json: { success_message: form.success_message.presence }, status: :created
  rescue Forms::SubmitService::InvalidSubmission => e
    render json: { message: e.message }, status: :unprocessable_entity
  end
end
