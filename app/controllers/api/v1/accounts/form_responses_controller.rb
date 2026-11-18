class Api::V1::Accounts::FormResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_form
  before_action :check_authorization

  def index
    @form_responses = @form.form_responses.includes(:ticket, :contact, :filled_by, :form_answers).ordered
  end

  def show
    @form_response = @form.form_responses.includes(:form_answers).find(params[:id])
  end

  # Preenchimento avulso, a partir do Artigo (POP) da Base de Conhecimento: vinculado a um chamado
  # pelo numero dele. Qualquer pessoa da conta preenche (so' criar/editar o Formulario e' do
  # administrador), por isso a checagem usa `show?` do Formulario.
  def create
    @form_response = Forms::FillService.new(
      form: @form, user: Current.user, ticket_display_id: params[:ticket_display_id],
      answers: params[:answers] || {}, files: params[:files] || {}
    ).perform
    render :show, status: :created
  rescue Forms::FillService::InvalidFill => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_form
    @form = Current.account.forms.find(params[:form_id])
  end

  def check_authorization(model = nil)
    return authorize(model || @form, :show?) if action_name == 'create'

    super(model || @form)
  end
end
