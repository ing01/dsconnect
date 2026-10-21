# A API de Integracao de Tickets - pensada para um sistema EXTERNO consumir
# (hoje: a IA de triagem de outro time), nao para o proprio painel. Fica fora
# do namespace `api/v1/accounts/:account_id` de proposito: a conta vem da
# chave (`TicketApiKeyAuth`), nao da URL, e os controllers aqui dentro nunca
# herdam de `Api::V1::Accounts::BaseController` (aquele exige login de
# usuario).
class Api::V1::Integrations::BaseController < Api::BaseController
  skip_before_action :authenticate_user!
  include TicketApiKeyAuth
end
