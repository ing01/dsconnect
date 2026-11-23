# Os numeros do Painel de Conversas (3 cards, indicadores, por agente/caixa e as
# listas de cada faixa). Cache curto por conta: varias pessoas com o painel
# aberto nao multiplicam a carga no banco.
class Api::V2::Accounts::ConversationPanelController < Api::V1::Accounts::BaseController
  CACHE_SECONDS = 5

  def show
    payload = Rails.cache.fetch(cache_key, expires_in: CACHE_SECONDS.seconds) do
      ConversationPanel::Builder.new(Current.account).perform.as_json
    end

    render json: payload
  rescue StandardError => e
    # Diagnostico (remover depois de estabilizar): so chega aqui quem ja passou
    # na autorizacao, entao devolve o motivo real em vez de um 500 mudo.
    Rails.logger.error("[ConversationPanel] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    render json: { error: "#{e.class}: #{e.message}", where: e.backtrace.first(5) }, status: :internal_server_error
  end

  private

  def check_authorization
    authorize :conversation_panel, :show?
  end

  # Os tempos entram na chave: mudar a configuracao reflete na hora.
  def cache_key
    setting = ConversationPanelSetting.for(Current.account)
    ['conversation_panel', Current.account.id, setting.orange_until_minutes, setting.list_limit].join(':')
  end
end
