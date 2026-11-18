class Api::V1::Accounts::FormResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_form
  before_action :check_authorization

  def index
    @form_responses = @form.form_responses.includes(:ticket, :filled_by, :form_answers).ordered
  end

  def show
    @form_response = @form.form_responses.includes(:form_answers).find(params[:id])
  end

  private

  def fetch_form
    @form = Current.account.forms.find(params[:form_id])
  end

  def check_authorization(model = nil)
    super(model || @form)
  end
end
