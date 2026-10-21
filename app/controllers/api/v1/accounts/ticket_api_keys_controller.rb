# Gestao da chave da API de Integracao de Tickets - Configuracoes >
# Integracoes > API de Tickets. So' admin: a chave da conta inteira sendo
# gerada por qualquer agente seria um jeito facil de um atendente comum criar
# um acesso externo sem o administrador saber.
class Api::V1::Accounts::TicketApiKeysController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    @ticket_api_key = Current.account.ticket_api_key
  end

  # Gerar sempre SUBSTITUI a chave anterior - uma por conta de proposito (ver
  # TicketApiKey). O token completo so' vem nesta resposta; dali em diante a
  # tela so mostra a versao mascarada.
  def create
    @ticket_api_key = Current.account.ticket_api_key || Current.account.build_ticket_api_key
    @ticket_api_key.persisted? ? @ticket_api_key.regenerate_token : @ticket_api_key.save!
    render 'show', locals: { reveal_token: true }
  end

  def destroy
    Current.account.ticket_api_key&.destroy!
    head :ok
  end
end
