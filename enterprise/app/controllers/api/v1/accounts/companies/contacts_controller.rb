class Api::V1::Accounts::Companies::ContactsController < Api::V1::Accounts::Companies::BaseController
  RESULTS_PER_PAGE = 15
  CONTACT_SEARCH_QUERY = [
    'contacts.name ILIKE :search',
    'contacts.email ILIKE :search',
    'contacts.phone_number ILIKE :search',
    'contacts.identifier ILIKE :search'
  ].join(' OR ')

  before_action :authorize_company_read!, only: [:index, :search]
  before_action :authorize_company_update!, only: [:create, :destroy]
  before_action :set_current_page, only: [:index, :search]
  before_action :fetch_contact, only: [:destroy]

  # Lists the contacts that belong to this Empresa. An optional `q` narrows the
  # list server-side, so a picker over a company with more contacts than one page
  # still finds them - `search` below is the opposite query (contacts NOT in the
  # company, for assigning) and cannot serve this.
  def index
    scope = @company.member_contacts.order(:name, :id)
    scope = scope.where(CONTACT_SEARCH_QUERY, search: "%#{params[:q].strip}%") if params[:q].present?
    @contacts = fetch_contacts(scope)
    @contacts_count = @contacts.total_count
  end

  def search
    if params[:q].blank?
      return render json: { error: 'Specify search string with parameter q' },
                    status: :unprocessable_entity
    end

    @contacts = fetch_contacts(contact_search_scope)
    @contacts_count = @contacts.total_count
  end

  def create
    @contact = Current.account.contacts.find(params[:contact_id])
    membership_service.assign(contact: @contact)
  end

  def destroy
    membership_service.remove(contact: @contact)
    head :ok
  end

  private

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_contact
    @contact = @company.member_contacts.find(params[:id])
  end

  def fetch_contacts(contacts)
    contacts
      .includes({ avatar_attachment: [:blob] }, :company)
      .page(@current_page)
      .per(RESULTS_PER_PAGE)
  end

  def contact_search_scope
    Current.account.contacts
           .where.not(id: CompanyContact.where(company_id: @company.id).select(:contact_id))
           .where(CONTACT_SEARCH_QUERY, search: "%#{params[:q].strip}%")
           .order(:name, :id)
  end

  def membership_service
    @membership_service ||= Companies::ContactMembershipService.new(company: @company)
  end
end
