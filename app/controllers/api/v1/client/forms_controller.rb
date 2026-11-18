# Os formularios publicados que o cliente logado preenche pela Central de Ajuda (a Area do Cliente).
# So' os da conta dele e so' os publicados - formulario "aberto" tambem serve, o login so' o torna
# desnecessario para quem nao tem conta.
class Api::V1::Client::FormsController < Api::V1::Client::BaseController
  def show
    form = current_contact.account.forms.published.find(params[:id])
    render json: render_partial_json(form)
  end

  private

  def render_partial_json(form)
    JSON.parse(ApplicationController.render(partial: 'api/v1/models/public_form', formats: [:json], locals: { resource: form }))
  end
end
