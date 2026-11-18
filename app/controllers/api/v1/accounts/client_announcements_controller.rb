# Configuracoes > Avisos do Portal: o administrador cadastra os avisos do Mural
# que o cliente ve no Principal e no modal ao entrar.
class Api::V1::Accounts::ClientAnnouncementsController < Api::V1::Accounts::BaseController
  before_action :fetch_announcement, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @announcements = Current.account.client_announcements.ordered
  end

  def create
    @announcement = Current.account.client_announcements.new(announcement_params)
    @announcement.created_by = Current.user
    @announcement.position = Current.account.client_announcements.maximum(:position).to_i + 1 unless params[:client_announcement].key?(:position)
    @announcement.save!
  end

  def update
    @announcement.update!(announcement_params)
  end

  def destroy
    @announcement.destroy!
    head :ok
  end

  private

  def fetch_announcement
    @announcement = Current.account.client_announcements.find(params[:id])
  end

  def announcement_params
    params.require(:client_announcement).permit(
      :title, :body, :kind, :starts_at, :ends_at, :link_url, :link_label,
      :position, :active, :audience,
      company_ids: [], company_niche_ids: [], company_sub_niche_ids: [], client_levels: []
    )
  end
end
