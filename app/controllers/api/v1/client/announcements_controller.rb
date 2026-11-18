# O que o cliente ve no Mural de Avisos: os avisos ativos, dentro da janela de
# datas e destinados as Empresas do contato logado.
class Api::V1::Client::AnnouncementsController < Api::V1::Client::BaseController
  def index
    companies = Company.where(account_id: Current.account.id, id: current_contact.client_company_ids)
    announcements = Current.account.client_announcements.currently_visible.for_display
                           .select { |announcement| announcement.visible_to?(companies) }

    render json: { announcements: announcements.map { |announcement| announcement_json(announcement) } }
  end

  private

  def announcement_json(announcement)
    {
      id: announcement.id,
      title: announcement.title,
      body: announcement.body,
      kind: announcement.kind,
      link_url: announcement.link_url,
      link_label: announcement.link_label,
      starts_at: announcement.starts_at,
      ends_at: announcement.ends_at
    }
  end
end
