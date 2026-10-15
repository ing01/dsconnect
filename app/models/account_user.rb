# == Schema Information
#
# Table name: account_users
#
#  id                       :bigint           not null, primary key
#  active_at                :datetime
#  auto_offline             :boolean          default(TRUE), not null
#  availability             :integer          default("online"), not null
#  role                     :integer          default("agent")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint
#  agent_capacity_policy_id :bigint
#  custom_role_id           :bigint
#  inviter_id               :bigint
#  user_id                  :bigint
#
# Indexes
#
#  index_account_users_on_account_id                (account_id)
#  index_account_users_on_agent_capacity_policy_id  (agent_capacity_policy_id)
#  index_account_users_on_custom_role_id            (custom_role_id)
#  index_account_users_on_user_id                   (user_id)
#  uniq_user_id_per_account_id                      (account_id,user_id) UNIQUE
#

class AccountUser < ApplicationRecord
  include AvailabilityStatusable

  belongs_to :account
  belongs_to :user
  belongs_to :inviter, class_name: 'User', optional: true

  enum role: { agent: 0, administrator: 1 }
  enum availability: { online: 0, offline: 1, busy: 2 }

  accepts_nested_attributes_for :account

  after_create_commit :notify_creation, :create_notification_setting
  after_destroy :notify_deletion, :remove_user_from_account
  after_save :update_presence_in_redis, if: :saved_change_to_availability?
  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :filtered_unread_count_visibility_changed?

  validates :user_id, uniqueness: { scope: :account_id }

  # Horario de almoco do agente - opcional (todas as 4 colunas nulas = sem
  # almoco cadastrado). So existe este par (inicio/fim), sem dia da semana:
  # o mesmo horario vale todo dia. Ver `lunch_blackout_now?`.
  validates :lunch_start_hour, :lunch_end_hour, inclusion: { in: 0..23 }, allow_nil: true
  validates :lunch_start_minutes, :lunch_end_minutes, inclusion: { in: 0..59 }, allow_nil: true
  validate :lunch_break_fully_set_or_unset
  validate :lunch_end_after_start

  # Fuso fixo: o sistema e' pt_BR unico (mesma premissa de ClientAreaLocale),
  # e nem User/AccountUser nem Account tem fuso proprio hoje - so Inbox/Team.
  LUNCH_TIMEZONE = 'America/Sao_Paulo'.freeze
  # Tempo antes do inicio do almoco em que o agente para de receber
  # distribuicao automatica - pedido explicito: 20 minutos.
  LUNCH_BLACKOUT_BUFFER = 20.minutes

  def lunch_break_configured?
    lunch_start_hour.present? && lunch_start_minutes.present? &&
      lunch_end_hour.present? && lunch_end_minutes.present?
  end

  # Verdadeiro desde 20 minutos antes do inicio do almoco (`LUNCH_BLACKOUT_BUFFER`)
  # at o fim dele. Fora dessa janela, o agente volta a entrar na distribuicao
  # normalmente - nao precisa de nenhuma acao manual pra "reativar".
  def lunch_blackout_now?(at: Time.zone.now)
    return false unless lunch_break_configured?

    local_now = at.in_time_zone(LUNCH_TIMEZONE)
    blackout_start = local_now.change(hour: lunch_start_hour, min: lunch_start_minutes) - LUNCH_BLACKOUT_BUFFER
    lunch_end = local_now.change(hour: lunch_end_hour, min: lunch_end_minutes)

    local_now.between?(blackout_start, lunch_end)
  end

  # IDs (User) de quem esta no bloqueio de almoco agora, para a conta dada.
  # Usado pela distribuicao automatica (InboxAgentAvailability) pra excluir
  # esses agentes sem tocar no status online/offline deles - o agente
  # continua "online" pro resto do sistema (conversas atribuidas, etc), so
  # para de RECEBER novas.
  def self.lunch_blackout_user_ids(account_id)
    where(account_id: account_id).where.not(lunch_start_hour: nil)
                                 .select(&:lunch_blackout_now?)
                                 .map(&:user_id)
  end

  def create_notification_setting
    setting = user.notification_settings.new(account_id: account.id)
    setting.selected_email_flags = [:email_conversation_assignment]
    # Mensagem do Chat Interno e dirigida a pessoa, como a atribuicao de
    # conversa: entra ligada por padrao. Sem isto, o tipo nasceria desligado
    # para toda conta nova e ninguem saberia que existe.
    # Resposta do cliente num ticket entra ligada por padrao pelo mesmo
    # motivo: so chega a quem e responsavel/segue o chamado (ver
    # Tickets::CustomerCommunicationNotificationBuilder), entao nao ha risco
    # de lotar a bandeja de quem nao tem nada a ver com aquele ticket.
    setting.selected_push_flags = %i[
      push_conversation_assignment push_internal_chat_message push_ticket_customer_communication_received
    ]
    setting.save!
  end

  def remove_user_from_account
    ::Agents::DestroyJob.perform_later(account, user)
  end

  def permissions
    administrator? ? ['administrator'] : ['agent']
  end

  def push_event_data
    {
      id: id,
      availability: availability,
      role: role,
      user_id: user_id
    }
  end

  private

  def notify_creation
    Rails.configuration.dispatcher.dispatch(AGENT_ADDED, Time.zone.now, account: account)
  end

  def notify_deletion
    Rails.configuration.dispatcher.dispatch(AGENT_REMOVED, Time.zone.now, account: account)
  end

  def update_presence_in_redis
    OnlineStatusTracker.set_status(account.id, user.id, availability)
  end

  def filtered_unread_count_visibility_changed?
    previous_changes.key?('role') || previous_changes.key?('custom_role_id')
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).user_visibility_changed!(user_id: user_id)
  end

  def invalidate_filtered_unread_count_visibility_update
    dispatch_account_cache_invalidated if invalidate_filtered_unread_count_visibility
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end

  def lunch_fields
    [lunch_start_hour, lunch_start_minutes, lunch_end_hour, lunch_end_minutes]
  end

  def lunch_break_fully_set_or_unset
    return if lunch_fields.all?(&:nil?) || lunch_fields.all?(&:present?)

    errors.add(:base, I18n.t('errors.account_user.lunch_break_incomplete'))
  end

  def lunch_end_after_start
    return unless lunch_break_configured?
    return if (lunch_end_hour.hours + lunch_end_minutes.minutes) > (lunch_start_hour.hours + lunch_start_minutes.minutes)

    errors.add(:base, I18n.t('errors.account_user.lunch_break_end_before_start'))
  end
end

AccountUser.prepend_mod_with('AccountUser')
AccountUser.include_mod_with('Audit::AccountUser')
AccountUser.include_mod_with('Concerns::AccountUser')
