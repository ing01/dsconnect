# Configuracoes > Painel de Conversas: os tempos das faixas e o ritmo de
# atualizacao. So' administrador.
class Api::V1::Accounts::ConversationPanelSettingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: setting_json(ConversationPanelSetting.for(Current.account))
  end

  def update
    setting = ConversationPanelSetting.for(Current.account)
    setting.update!(setting_params)
    render json: setting_json(setting)
  end

  private

  def check_authorization
    authorize :conversation_panel, :update?
  end

  def setting_params
    params.require(:conversation_panel_setting)
          .permit(:green_until_minutes, :orange_until_minutes, :refresh_seconds, :list_limit, :sound_enabled)
  end

  def setting_json(setting)
    setting.slice(:green_until_minutes, :orange_until_minutes, :refresh_seconds, :list_limit, :sound_enabled)
  end
end
