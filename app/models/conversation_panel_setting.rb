# == Schema Information
#
# Table name: conversation_panel_settings
#
#  id                   :bigint           not null, primary key
#  green_until_minutes  :integer          default(5), not null
#  list_limit           :integer          default(50), not null
#  orange_until_minutes :integer          default(15), not null
#  refresh_seconds      :integer          default(30), not null
#  sound_enabled        :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#
# Indexes
#
#  index_conversation_panel_settings_on_account_id  (account_id) UNIQUE
#

# Configuracao do Painel de Conversas (uma por conta): os tempos que separam os
# tres cards e o ritmo de atualizacao. Sem registro, vale o padrao da tabela
# (`ConversationPanelSetting.for(account)` devolve um registro novo, nao salvo).
class ConversationPanelSetting < ApplicationRecord
  belongs_to :account

  validates :green_until_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 1440 }
  validates :orange_until_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 10_080 }
  validates :refresh_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 10, less_than_or_equal_to: 300 }
  validates :list_limit, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than_or_equal_to: 200 }
  validate :orange_after_green

  def self.for(account)
    account.conversation_panel_setting || account.build_conversation_panel_setting
  end

  private

  def orange_after_green
    return if green_until_minutes.blank? || orange_until_minutes.blank?
    return if orange_until_minutes > green_until_minutes

    errors.add(:orange_until_minutes, I18n.t('conversation_panel.errors.orange_after_green'))
  end
end
