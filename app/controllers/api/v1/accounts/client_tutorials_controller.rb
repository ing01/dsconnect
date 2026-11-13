# A tela de Configuracoes > Tickets > Tutoriais do Portal: o administrador cadastra
# o titulo, o texto e o video (link ou arquivo) que o cliente ve na aba Tutoriais.
#
# O arquivo NAO passa por aqui: o navegador o envia direto ao storage
# (`ClientTutorials::DirectUploadsController`) e este controller so' recebe o
# `video_signed_id` do blob - o video pesa dezenas de MB.
class Api::V1::Accounts::ClientTutorialsController < Api::V1::Accounts::BaseController
  before_action :fetch_tutorial, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @tutorials = Current.account.client_tutorials.ordered.with_attached_video_file
  end

  def create
    @tutorial = Current.account.client_tutorials.new(tutorial_params)
    apply_video_source
    @tutorial.position = Current.account.client_tutorials.maximum(:position).to_i + 1 unless params[:client_tutorial].key?(:position)
    @tutorial.save!
  end

  def update
    @tutorial.assign_attributes(tutorial_params)
    previous_blob = @tutorial.video_file.blob if @tutorial.video_file.attached?
    apply_video_source
    @tutorial.save!
    purge_replaced(previous_blob)
  end

  def destroy
    @tutorial.destroy!
    head :ok
  end

  private

  def fetch_tutorial
    @tutorial = Current.account.client_tutorials.find(params[:id])
  end

  def tutorial_params
    params.require(:client_tutorial).permit(:title, :description, :video_url, :position, :active)
  end

  # Um OU o outro: arquivo novo limpa o link; link novo (ou "remover arquivo") tira o arquivo.
  def apply_video_source
    if params[:video_signed_id].present?
      @tutorial.video_file = params[:video_signed_id]
      @tutorial.video_url = nil
    elsif @tutorial.video_url.present? || ActiveModel::Type::Boolean.new.cast(params[:remove_video_file])
      @tutorial.video_file = nil
    end
  end

  # O arquivo trocado ou removido sai do storage depois de salvar com sucesso.
  def purge_replaced(previous_blob)
    return if previous_blob.blank?
    return if @tutorial.video_file.attached? && @tutorial.video_file.blob == previous_blob

    previous_blob.purge_later
  end
end
