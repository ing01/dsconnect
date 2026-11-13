# Configuracoes > Tutoriais do Portal > Modulos: o administrador cria os
# cards (DS Connect, DS Comercial...) em que os tutoriais ficam agrupados, cada um
# com seu logo.
#
# O logo chega como `logo_signed_id`: o navegador o envia direto ao storage pelo
# mesmo endpoint dos videos (`ClientTutorials::DirectUploadsController`).
class Api::V1::Accounts::ClientTutorialModulesController < Api::V1::Accounts::BaseController
  before_action :fetch_module, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @modules = Current.account.client_tutorial_modules.ordered.with_attached_logo
  end

  def create
    @module = Current.account.client_tutorial_modules.new(module_params)
    apply_logo
    @module.position = Current.account.client_tutorial_modules.maximum(:position).to_i + 1 unless params[:client_tutorial_module].key?(:position)
    @module.save!
  end

  def update
    @module.assign_attributes(module_params)
    previous_blob = @module.logo.blob if @module.logo.attached?
    apply_logo
    @module.save!
    purge_replaced(previous_blob)
  end

  def destroy
    @module.destroy!
    head :ok
  end

  private

  def fetch_module
    @module = Current.account.client_tutorial_modules.find(params[:id])
  end

  def module_params
    params.require(:client_tutorial_module).permit(:name, :description, :position, :active)
  end

  # Logo novo substitui o atual; `remove_logo` tira o logo sem pôr outro.
  def apply_logo
    if params[:logo_signed_id].present?
      @module.logo = params[:logo_signed_id]
    elsif ActiveModel::Type::Boolean.new.cast(params[:remove_logo])
      @module.logo = nil
    end
  end

  # O arquivo trocado ou removido sai do storage depois de salvar com sucesso.
  def purge_replaced(previous_blob)
    return if previous_blob.blank?
    return if @module.logo.attached? && @module.logo.blob == previous_blob

    previous_blob.purge_later
  end
end
