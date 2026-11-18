# O formulario ABERTO: qualquer pessoa com o link (o codigo aleatorio `public_token`) preenche, sem
# login. So' formularios publicados E marcados como "aberto" saem daqui - os de "so' logado" e os
# rascunhos respondem 404, como se nao existissem. Quem usa o codigo errado tambem recebe 404.
#
# Protecoes (e' uma porta aberta para a internet):
#   - limite por IP no Rack::Attack (ver config/initializers/rack_attack.rb);
#   - campo isca (`website`) que pessoa nao ve e robo costuma preencher: finge sucesso e nao grava;
#   - Forms::SubmitService valida as opcoes, o tamanho do texto e restringe os arquivos.
class Public::Api::V1::FormsController < PublicController
  before_action :set_form

  def show
    render json: JSON.parse(ApplicationController.render(partial: 'api/v1/models/public_form', formats: [:json],
                                                         locals: { resource: @form }))
                     .merge(ask_respondent: true)
  end

  def create
    return render json: { success_message: @form.success_message.presence }, status: :created if params[:website].present?

    Forms::SubmitService.new(
      form: @form, source: 'public', answers: params[:answers] || {}, files: params[:files] || {},
      respondent: { name: params[:respondent_name], email: params[:respondent_email] }
    ).perform
    render json: { success_message: @form.success_message.presence }, status: :created
  rescue Forms::SubmitService::InvalidSubmission => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def set_form
    @form = Form.published.where(access_mode: 'open').find_by!(public_token: params[:token])
  end
end
