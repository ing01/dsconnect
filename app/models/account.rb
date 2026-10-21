# == Schema Information
#
# Table name: accounts
#
#  id                    :integer          not null, primary key
#  auto_resolve_duration :integer
#  custom_attributes     :jsonb
#  domain                :string(100)
#  feature_flags         :bigint           default(0), not null
#  feature_flags_ext_1   :bigint           default(0), not null
#  internal_attributes   :jsonb            not null
#  limits                :jsonb
#  locale                :integer          default("en")
#  name                  :string           not null
#  settings              :jsonb
#  status                :integer          default("active")
#  support_email         :string(100)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_accounts_on_status  (status)
#

class Account < ApplicationRecord
  # used for multi-flag bitset columns
  include FlagShihTzu
  include Reportable
  include Featurable
  include CacheKeys
  include CaptainFeaturable
  include AccountEmailRateLimitable
  include AccountSettingsSchema

  DEFAULT_QUERY_SETTING = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze
  SUSPENSION_CATEGORIES = %w[spam non_payment other].freeze

  attr_accessor :suspension_category, :suspension_reason

  validates :name, presence: true
  # `domain` is the inbound email domain used to construct reply addresses
  # (see `inbound_email_domain`). Do not repurpose it for a website or any
  # non-mail-related domain.
  validates :domain, length: { maximum: 100 }
  validates_with JsonSchemaValidator,
                 schema: SETTINGS_PARAMS_SCHEMA,
                 attribute_resolver: ->(record) { record.settings }
  validate :validate_reporting_timezone
  validate :validate_support_email_format, if: :will_save_change_to_support_email?

  store_accessor :settings, :auto_resolve_after, :auto_resolve_message, :auto_resolve_ignore_waiting

  store_accessor :settings, :audio_transcriptions, :auto_resolve_label
  store_accessor :settings, :captain_models, :captain_features
  store_accessor :settings, :reporting_timezone
  store_accessor :settings, :keep_pending_on_bot_failure
  store_accessor :settings, :captain_auto_resolve_mode, :captain_false_promise_harness_enabled
  # WhatsApp helpdesk triage flow (AutomationRules::Flow) configuration - see
  # AutomationRules::Flow::BlockGateService and the ai_resolve/ai_triage steps.
  store_accessor :settings, :helpdesk_whatsapp_flow_enabled, :helpdesk_ai_resolve_levels,
                  :helpdesk_default_priority_on_ai_failure, :helpdesk_open_ticket_window_days,
                  :helpdesk_level_3to5_team_id, :helpdesk_default_queue_id,
                  :helpdesk_queue_low_id, :helpdesk_queue_high_id, :helpdesk_support_phone_number
  # Limiares de mensalidade que definem a Prioridade (Baixa/Media/Alta) de uma
  # Empresa - ver Company#tier_for. Abaixo de `priority_threshold_medium_min`
  # e' sempre Baixa.
  store_accessor :settings, :priority_threshold_medium_min, :priority_threshold_high_min
  # Trava temporaria de homologacao: com um numero configurado aqui, a
  # automacao (fluxo de triagem + Captain) do WhatsApp so responde a esse
  # numero - qualquer outro contato so recebe a mensagem registrada na
  # conversa, sem resposta automatica. Ver AutomationRules::Flow::BlockGateService
  # e Enterprise::MessageTemplates::HookExecutionService. Vazio = sem trava,
  # comportamento normal pra todo mundo.
  store_accessor :settings, :whatsapp_automation_test_mode_number
  # Distribuicao automatica de conversas de WhatsApp entre agentes - ver
  # AutoAssignment::AssignmentService#find_available_agent (e a versao
  # enterprise dele), unico ponto que le essas 3 chaves. `enabled` desligado
  # nunca impede atribuicao manual, so a automatica; `max_open_chats` em
  # branco = sem limite; `excluded_agent_ids` fica de fora da distribuicao
  # automatica mas continua podendo ser atribuido a mao.
  store_accessor :settings, :whatsapp_auto_assignment_enabled, :whatsapp_auto_assignment_max_open_chats,
                  :whatsapp_auto_assignment_excluded_agent_ids
  # Pesquisa de satisfacao por digito (1-5) no WhatsApp - ver
  # Whatsapp::CsatDigitSurveyService, unico lugar que le essas chaves.
  # Mensagem em branco cai no texto padrao (`whatsapp_csat_survey_message_or_default`).
  # `reply_window_minutes` em branco cai no padrao (`Whatsapp::CsatDigitSurveyService::DEFAULT_REPLY_WINDOW_MINUTES`).
  store_accessor :settings, :whatsapp_csat_survey_enabled, :whatsapp_csat_survey_message,
                  :whatsapp_csat_survey_reply_window_minutes
  # Configuracao de Atendimento: dias/horarios em que a triagem automatica
  # (AutomationRules::Flow) pode comecar - ver AttendanceWindow e
  # `within_attendance_hours?`. Mensagem em branco cai no texto padrao
  # (`attendance_offline_message_or_default`).
  store_accessor :settings, :attendance_schedule_enabled, :attendance_offline_message
  include AccountCaptainAutoResolve

  DEFAULT_WHATSAPP_CSAT_SURVEY_MESSAGE =
    'Como você avalia nosso atendimento? Responda com um número de 1 a 5, sendo 1 (péssimo) e 5 (ótimo).'.freeze

  DEFAULT_ATTENDANCE_OFFLINE_MESSAGE =
    'No momento estamos fora do horário de atendimento. Assim que retomarmos, ' \
    'vamos continuar por aqui.'.freeze

  # phone_number vem sempre em E.164 (+DDI...); nil/blank nunca "bate" com o
  # numero de teste, mesmo se o campo de teste tambem estiver vazio.
  def whatsapp_automation_allowed_for?(phone_number)
    test_number = whatsapp_automation_test_mode_number
    return true if test_number.blank?

    phone_number.present? && phone_number == test_number
  end

  def whatsapp_csat_survey_message_or_default
    whatsapp_csat_survey_message.presence || DEFAULT_WHATSAPP_CSAT_SURVEY_MESSAGE
  end

  def attendance_offline_message_or_default
    attendance_offline_message.presence || DEFAULT_ATTENDANCE_OFFLINE_MESSAGE
  end

  # Ausente (nil) = desligado - a Configuracao de Atendimento so passa a valer
  # depois que alguem liga o toggle na tela, mesmo que ja existam periodos
  # cadastrados (evita travar quem so estava testando a tela).
  def attendance_schedule_enabled?
    ActiveModel::Type::Boolean.new.cast(attendance_schedule_enabled)
  end

  # `at` sempre em UTC (o padrao do Rails); convertido aqui pro fuso da conta
  # antes de comparar contra os minutos gravados. Sem nenhum periodo
  # cadastrado ainda, considera sempre dentro do horario - a automacao nao
  # pode travar sozinha so porque a tela ainda nao foi preenchida.
  def within_attendance_hours?(at: Time.current)
    return true unless attendance_schedule_enabled?
    return true if attendance_windows.blank?

    local = at.in_time_zone(reporting_timezone.presence || 'UTC')
    attendance_windows.covers?(day_of_week: local.wday, minute_of_day: (local.hour * 60) + local.min)
  end

  # Ausente (nil) = ligado - so desliga quando alguem explicitamente desmarca
  # o toggle na tela (grava `false`).
  def whatsapp_auto_assignment_enabled?
    whatsapp_auto_assignment_enabled != false
  end

  has_many :account_users, dependent: :destroy_async
  has_many :agent_bot_inboxes, dependent: :destroy_async
  has_many :agent_bots, dependent: :destroy_async
  has_many :conversation_flows, dependent: :destroy_async
  has_many :api_channels, dependent: :destroy_async, class_name: '::Channel::Api'
  has_many :articles, dependent: :destroy_async, class_name: '::Article'
  has_many :assignment_policies, dependent: :destroy_async
  has_many :attendance_windows, dependent: :destroy_async
  has_many :automation_rules, dependent: :destroy_async
  has_many :automation_rule_pending_executions, dependent: :delete_all
  has_many :macros, dependent: :destroy_async
  has_many :campaigns, dependent: :destroy_async
  has_many :calendar_events, dependent: :destroy_async
  has_many :canned_responses, dependent: :destroy_async
  has_many :categories, dependent: :destroy_async, class_name: '::Category'
  has_many :client_push_subscriptions, dependent: :destroy_async
  has_many :contacts, dependent: :destroy_async
  has_many :conversations, dependent: :destroy_async
  has_many :csat_survey_responses, dependent: :destroy_async
  has_many :custom_attribute_definitions, dependent: :destroy_async
  has_many :custom_filters, dependent: :destroy_async
  has_many :dashboard_apps, dependent: :destroy_async
  has_many :data_imports, dependent: :destroy_async
  has_many :email_channels, dependent: :destroy_async, class_name: '::Channel::Email'
  has_many :facebook_pages, dependent: :destroy_async, class_name: '::Channel::FacebookPage'
  has_many :instagram_channels, dependent: :destroy_async, class_name: '::Channel::Instagram'
  has_many :tiktok_channels, dependent: :destroy_async, class_name: '::Channel::Tiktok'
  has_many :hooks, dependent: :destroy_async, class_name: 'Integrations::Hook'
  has_many :inboxes, dependent: :destroy_async
  has_many :labels, dependent: :destroy_async
  has_many :line_channels, dependent: :destroy_async, class_name: '::Channel::Line'
  has_many :mentions, dependent: :destroy_async
  has_many :messages, dependent: :destroy_async
  has_many :mood_entries, dependent: :destroy_async
  has_many :notes, dependent: :destroy_async
  has_many :notification_settings, dependent: :destroy_async
  has_many :notifications, dependent: :destroy_async
  has_many :portals, dependent: :destroy_async, class_name: '::Portal'
  has_many :sms_channels, dependent: :destroy_async, class_name: '::Channel::Sms'
  # The service catalogue used to classify an attendance. Independent of the
  # Mesa: one Mesa attends several catalogues.
  has_many :service_catalogs, dependent: :destroy_async
  has_many :teams, dependent: :destroy_async
  has_many :queues, class_name: 'ServiceQueue', dependent: :destroy_async
  has_many :ticket_imports, dependent: :destroy_async
  # A API de Integracao de Tickets (ver Api::V1::Integrations) - uma chave por
  # conta, gerada em Configuracoes > Integracoes.
  has_one :ticket_api_key, dependent: :destroy
  has_many :ticket_routing_rules, dependent: :destroy_async
  # A Complexidade e da CONTA, e nao da Mesa: o nome e o mesmo em toda a empresa,
  # e quais Mesas oferecem cada nivel mora em `ticket_complexity_teams`.
  has_many :ticket_complexities, dependent: :destroy_async
  # Estagios live under a Mesa; reached through it so account-scoped lookups
  # (a transfer target, a stage select) don't have to join by hand.
  has_many :ticket_columns, through: :teams
  has_many :telegram_channels, dependent: :destroy_async, class_name: '::Channel::Telegram'
  has_many :tickets, dependent: :destroy_async
  # Os apontamentos ja pendem do ticket; a associacao pela conta e o que permite
  # o relatorio somar horas sem passar por cada ticket.
  has_many :ticket_time_entries, dependent: :destroy_async
  has_many :projects, dependent: :destroy_async
  # Painel de CRM Comercial - cadastro proprio, independente de `companies`.
  has_many :crm_clients, class_name: 'Crm::Client', dependent: :destroy_async
  has_many :crm_sales, class_name: 'Crm::Sale', dependent: :destroy_async
  has_many :crm_contract_templates, class_name: 'Crm::ContractTemplate', dependent: :destroy_async
  has_many :crm_generated_contracts, class_name: 'Crm::GeneratedContract', dependent: :destroy_async
  has_many :project_modules, dependent: :destroy_async
  # Quadro de Sugestoes de melhoria - 1 por conta, nao por Mesa.
  has_many :suggestion_categories, dependent: :destroy_async
  has_many :suggestion_columns, dependent: :destroy_async
  has_many :suggestion_priorities, dependent: :destroy_async
  has_many :suggestions, dependent: :destroy_async
  # O SAC do Portal do Cliente.
  has_many :manifestations, dependent: :destroy_async
  # A avaliacao mensal de satisfacao do Portal do Cliente.
  has_many :monthly_satisfaction_surveys, dependent: :destroy_async
  has_many :project_task_templates, dependent: :destroy_async
  has_many :checklists, dependent: :destroy_async
  # Os relogios de SLA dos tickets da conta, que a varredura de vencimentos
  # percorre (Tickets::Sla::SweepAccountJob).
  has_many :ticket_applied_slas, dependent: :destroy_async
  has_many :twilio_sms, dependent: :destroy_async, class_name: '::Channel::TwilioSms'
  has_many :twitter_profiles, dependent: :destroy_async, class_name: '::Channel::TwitterProfile'
  has_many :users, through: :account_users
  has_many :web_widgets, dependent: :destroy_async, class_name: '::Channel::WebWidget'
  has_many :webhooks, dependent: :destroy_async
  has_many :whatsapp_channels, dependent: :destroy_async, class_name: '::Channel::Whatsapp'
  has_many :working_hours, dependent: :destroy_async

  has_one_attached :contacts_export

  enum :locale, LANGUAGES_CONFIG.map { |key, val| [val[:iso_639_1_code], key] }.to_h, prefix: true
  enum :status, { active: 0, suspended: 1 }

  scope :with_auto_resolve, -> { where("(settings ->> 'auto_resolve_after')::int IS NOT NULL") }

  before_validation :validate_limit_keys
  after_create_commit :notify_creation
  after_update_commit :clear_unread_conversation_counts_cache, if: :saved_change_to_feature_conversation_unread_counts?
  after_update :resume_delayed_automations, if: -> { saved_change_to_feature_delayed_automations? && feature_delayed_automations? }
  after_destroy :remove_account_sequences

  def agents
    users.where(account_users: { role: :agent })
  end

  def administrators
    users.where(account_users: { role: :administrator })
  end

  def all_conversation_tags
    # returns array of tags
    conversation_ids = conversations.pluck(:id)
    ActsAsTaggableOn::Tagging.includes(:tag)
                             .where(context: 'labels',
                                    taggable_type: 'Conversation',
                                    taggable_id: conversation_ids)
                             .map { |tagging| tagging.tag.name }
  end

  def webhook_data
    {
      id: id,
      name: name
    }
  end

  def suspension_history
    internal_attributes['suspensions'] || []
  end

  def inbound_email_domain
    domain.presence || GlobalConfig.get('MAILER_INBOUND_EMAIL_DOMAIN')['MAILER_INBOUND_EMAIL_DOMAIN'] || ENV.fetch('MAILER_INBOUND_EMAIL_DOMAIN',
                                                                                                                   false)
  end

  def support_email
    super.presence || ENV.fetch('MAILER_SENDER_EMAIL') { GlobalConfig.get('MAILER_SUPPORT_EMAIL')['MAILER_SUPPORT_EMAIL'] }
  end

  def usage_limits
    {
      agents: ChatwootApp.max_limit.to_i,
      inboxes: ChatwootApp.max_limit.to_i
    }
  end

  def api_and_webhooks_enabled?
    true
  end

  def locale_english_name
    # the locale can also be something like pt_BR, en_US, fr_FR, etc.
    # the format is `<locale_code>_<country_code>`
    # we need to extract the language code from the locale
    account_locale = locale&.split('_')&.first
    ISO_639.find(account_locale)&.english_name&.downcase || 'english'
  end

  def onboarding_step
    step = custom_attributes['onboarding_step']
    return nil if step.blank?

    enrichment_key = format(Redis::Alfred::ACCOUNT_ONBOARDING_ENRICHMENT, account_id: id)
    Redis::Alfred.exists?(enrichment_key) ? 'enrichment' : step
  end

  def reset_cache_keys
    super
    clear_unread_conversation_counts_cache
  end

  private

  def notify_creation
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CREATED, Time.zone.now, account: self)
  end

  def clear_unread_conversation_counts_cache
    ::Conversations::UnreadCounts::Store.clear_account!(id)
  end

  def resume_delayed_automations
    AutomationRulePendingExecution.reschedule_paused(self)
  end

  trigger.after(:insert).for_each(:row) do
    "execute format('create sequence IF NOT EXISTS conv_dpid_seq_%s', NEW.id);"
  end

  trigger.name('camp_dpid_before_insert').after(:insert).for_each(:row) do
    "execute format('create sequence IF NOT EXISTS camp_dpid_seq_%s', NEW.id);"
  end

  def validate_limit_keys
    # method overridden in enterprise module
  end

  def validate_reporting_timezone
    return if reporting_timezone.blank? || ActiveSupport::TimeZone[reporting_timezone].present?

    errors.add(:reporting_timezone, I18n.t('errors.account.reporting_timezone.invalid'))
  end

  def validate_support_email_format
    value = attributes['support_email']
    return if value.blank?

    parsed = Mail::Address.new(value).address
    errors.add(:support_email, I18n.t('errors.account.support_email.invalid')) if parsed.blank?
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    errors.add(:support_email, I18n.t('errors.account.support_email.invalid'))
  end

  def remove_account_sequences
    ActiveRecord::Base.connection.exec_query("drop sequence IF EXISTS camp_dpid_seq_#{id}")
    ActiveRecord::Base.connection.exec_query("drop sequence IF EXISTS conv_dpid_seq_#{id}")
  end
end

Account.prepend_mod_with('Account')
Account.prepend_mod_with('Account::PlanUsageAndLimits')
Account.include_mod_with('Concerns::Account')
Account.include_mod_with('Audit::Account')
