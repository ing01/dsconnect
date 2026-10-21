# A chave usada pela API de Integracao de Tickets (ver
# Api::V1::Integrations::BaseController) - o jeito de um sistema EXTERNO (ex:
# a IA de triagem de outro time) ler/rotear tickets sem precisar logar como um
# usuario. Uma por conta de proposito: "gerar nova" sempre substitui a
# anterior (regenerate_token! do has_secure_token), sem precisar de tela de
# "varias chaves" que ninguem pediu ainda.
class TicketApiKey < ApplicationRecord
  belongs_to :account

  has_secure_token :token

  validates :account_id, uniqueness: true
end
