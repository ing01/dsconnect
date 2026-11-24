# Os numeros do Painel de Conversas (3 cards, indicadores, por agente/caixa e as
# listas de cada faixa). Cache curto por conta: varias pessoas com o painel
# aberto nao multiplicam a carga no banco.
class Api::V2::Accounts::ConversationPanelController < Api::V1::Accounts::BaseController
  CACHE_SECONDS = 5

  def show
    payload = Rails.cache.fetch(cache_key, expires_in: CACHE_SECONDS.seconds) do
      ConversationPanel::Builder.new(Current.account, queue_id: queue_id).perform.as_json
    end

    render json: payload
  end

  private

  def check_authorization
    authorize :conversation_panel, :show?
  end

  # So' aceita fila DA CONTA; qualquer outro valor vira "todas as filas".
  def queue_id
    return @queue_id if defined?(@queue_id)

    @queue_id = params[:queue_id].present? ? ServiceQueue.where(account_id: Current.account.id).find_by(id: params[:queue_id])&.id : nil
  end

  # Os tempos e a fila entram na chave: mudar a configuracao reflete na hora.
  def cache_key
    setting = ConversationPanelSetting.for(Current.account)
    ['conversation_panel', Current.account.id, setting.orange_until_minutes, setting.list_limit, queue_id].join(':')
  end
end
