class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      # Opcional. Com senha o agente ja entra direto; sem ela o convite por
      # e-mail continua sendo o caminho.
      password: new_agent_params['password'],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
    # A tela precisa saber quando a senha NAO foi aplicada - e-mail que ja
    # existia - para nao dizer a quem criou que definiu um acesso que nao
    # definiu.
    @password_applied = builder.password_applied?
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    # `.compact` tira os campos ausentes do payload (ex: tela nao manda
    # `enforce_queue_order` quando nao mudou) - mas os 4 campos de almoco
    # precisam poder chegar como `nil` de proposito, pra "apagar" um horario
    # ja cadastrado. Por isso saem do `.compact` e entram sempre, se vieram
    # no payload.
    lunch_attributes = [:lunch_start_hour, :lunch_start_minutes, :lunch_end_hour, :lunch_end_minutes]
    account_user_params = agent_params.slice(*(account_user_attributes - lunch_attributes)).compact
    # `slice` so traz as chaves que vieram de verdade no payload - um `merge!`
    # incondicional nao sobrescreve nada quando a tela nao manda nenhuma delas.
    account_user_params.merge!(agent_params.slice(*lunch_attributes))

    @agent.current_account_user.update!(account_user_params)
  end

  # Define uma senha nova para um agente desta conta.
  #
  # Existe porque a redefinicao normal depende do e-mail de recuperacao, que nao
  # chega onde nao ha SMTP. Nao substitui aquele fluxo: e um atalho
  # administrativo, restrito a administradores pela UserPolicy#update?.
  def reset_password
    return render_cross_account_error unless resettable?(@agent)

    @agent.password = params[:password]
    @agent.password_confirmation = params[:password]
    # Uma senha definida por administrador tambem confirma a conta: sem isso o
    # agente teria senha e ainda assim nao entraria.
    @agent.skip_confirmation! unless @agent.confirmed?
    @agent.save!

    head :ok
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    bulk_create_agents(emails)
    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    clear_onboarding_step
    head :ok
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  private

  def check_authorization
    super(User)
  end

  # So agentes que pertencem unicamente a esta conta.
  #
  # Um User do Chatwoot e global: o mesmo cadastro pode estar em varias contas,
  # eventualmente como administrador de outra. Trocar a senha dele aqui daria a
  # um administrador desta conta o acesso a outra - por isso a recusa.
  def resettable?(agent)
    agent.account_users.count == 1 && agent.account_users.first.account_id == Current.account.id
  end

  def render_cross_account_error
    render json: { error: I18n.t('errors.agents.password_reset_not_allowed') }, status: :unprocessable_entity
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline, :enforce_queue_order,
     :lunch_start_hour, :lunch_start_minutes, :lunch_end_hour, :lunch_end_minutes]
  end

  def allowed_agent_params
    [:name, :email, :role, :availability, :auto_offline, :enforce_queue_order,
     :lunch_start_hour, :lunch_start_minutes, :lunch_end_hour, :lunch_end_minutes]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline, :password)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def bulk_create_agents(emails)
    email_limit_error = nil

    Current.account.with_lock do
      raise AgentBuilder::LimitExceededError if emails.count > available_agent_count

      emails.each do |email|
        create_agent_from_email(email)
      rescue CustomExceptions::Account::EmailLimitExceeded => e
        email_limit_error = e
      end
    end

    raise email_limit_error if email_limit_error
  end

  def create_agent_from_email(email)
    builder = AgentBuilder.new(
      email: email,
      name: email.split('@').first,
      inviter: current_user,
      account: Current.account
    )
    builder.perform
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
  end

  def clear_onboarding_step
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - Current.account.account_users.count
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
