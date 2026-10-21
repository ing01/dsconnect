# Autenticacao da API de Integracao de Tickets (Api::V1::Integrations::*) -
# um sistema EXTERNO (nao um usuario logado), por isso NAO seta `Current.user`:
# nao ha ator humano por tras da chamada. A conta e resolvida pela CHAVE, nao
# pela URL - e por isso esses controllers nao vivem sob `accounts/:account_id`.
module TicketApiKeyAuth
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_ticket_api_key!
  end

  private

  def authenticate_ticket_api_key!
    key = TicketApiKey.find_by(token: request.headers['X-Ticket-Api-Key'])
    return render json: { error: 'unauthorized' }, status: :unauthorized if key.blank?

    @current_account = key.account
    # Mesmo interruptor por conta que a API do painel ja respeita
    # (Api::V1::Accounts::BaseController#validate_token_api_access) - desligar
    # a API nas Configuracoes da conta tambem corta esta.
    return render json: { error: 'api disabled for this account' }, status: :forbidden unless current_account.api_and_webhooks_enabled?

    key.update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def current_account
    @current_account
  end
end
