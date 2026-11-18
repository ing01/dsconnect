class Api::V1::Accounts::FormsController < Api::V1::Accounts::BaseController
  before_action :fetch_form, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @forms = Current.account.forms.ordered
  end

  def show; end

  def create
    @form = Current.account.forms.new(form_params)
    normalize_fields!
    @form.save!
  end

  def update
    @form.assign_attributes(form_params)
    normalize_fields!
    @form.save!
    render 'show'
  end

  def destroy
    @form.destroy!
    head :ok
  end

  private

  def fetch_form
    @form = Current.account.forms.find(params[:id])
  end

  def form_params
    params.require(:form).permit(
      :name, :description, :status, :article_id, theme: {},
                                                   fields: [:id, :label, :description, :field_type, :required, options: []]
    )
  end

  # A posicao de cada pergunta e' sempre a ordem em que o front manda o array -
  # nunca confiada ao que o cliente diga em `position`, pra reordenar
  # (arrastar) nunca dessincronizar da ordem de verdade.
  def normalize_fields!
    return unless form_params.key?(:fields)

    @form.fields = form_params[:fields].each_with_index.map do |field, index|
      Form.field_attributes_from(field.to_h, index)
    end
  end
end
