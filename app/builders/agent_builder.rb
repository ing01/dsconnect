# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  LIMIT_EXCEEDED_MESSAGE = 'Account limit exceeded. Please purchase more licenses'.freeze

  class LimitExceededError < StandardError
    def initialize
      super(AgentBuilder::LIMIT_EXCEEDED_MESSAGE)
    end
  end

  # Initializes an AgentBuilder with necessary attributes.
  # @param email [String] the email of the user.
  # @param name [String] the name of the user.
  # @param role [String] the role of the user, defaults to 'agent' if not provided.
  # @param inviter [User] the user who is inviting the agent (Current.user in most cases).
  # @param availability [String] the availability status of the user, defaults to 'offline' if not provided.
  # @param auto_offline [Boolean] the auto offline status of the user.
  # @param password [String] senha inicial escolhida por quem cria. Opcional:
  #   sem ela o fluxo segue como sempre foi, por e-mail de convite.
  pattr_initialize [:email, { name: '' }, :inviter, :account, { role: :agent }, { availability: :offline },
                    { auto_offline: false }, { password: nil }]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    account.with_lock do
      raise LimitExceededError unless can_add_agent?

      ActiveRecord::Base.transaction(requires_new: true) do
        @user = find_or_create_user
        create_account_user
        reserve_invitation_email_capacity if user_needs_confirmation?
      end
    end
    @user.send_confirmation_instructions if user_needs_confirmation?
    @user
  end

  # Diz a quem chamou se a senha informada foi de fato usada. Falso quando o
  # e-mail ja pertencia a alguem: a tela precisa avisar em vez de deixar quem
  # criou achar que definiu uma senha que nao definiu.
  def password_applied?
    @new_user && password.present?
  end

  private

  def can_add_agent?
    account.usage_limits[:agents] > account.account_users.count
  end

  # Finds a user by email or creates a new one.
  #
  # A senha informada vale SO para usuario novo. Um e-mail que ja existe
  # devolve a pessoa que ja esta cadastrada - possivelmente de outra conta -, e
  # sobrescrever a senha dela aqui deixaria qualquer administrador tomar o
  # acesso de quem ele conseguisse adivinhar o e-mail.
  # @return [User] the found or created user.
  def find_or_create_user
    @new_user = false
    user = User.from_email(email)
    return user if user

    @name = email.split('@').first if @name.blank?
    chosen_password = password.presence || "1!aA#{SecureRandom.alphanumeric(12)}"
    User.new(email: email, name: @name, password: chosen_password, password_confirmation: chosen_password).tap do |new_user|
      new_user.skip_confirmation_notification!
      # Com senha definida na criacao o agente ja entra direto, sem depender do
      # e-mail de confirmacao - que e justamente o que nao chega onde nao ha
      # SMTP configurado.
      new_user.skip_confirmation! if password.present?
      new_user.save!
      @new_user = true
    end
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    @new_user && @user.persisted? && !@user.confirmed?
  end

  def reserve_invitation_email_capacity
    return if account.reserve_email_send_capacity

    raise CustomExceptions::Account::EmailLimitExceeded.new({})
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }.compact))
  end
end

AgentBuilder.prepend_mod_with('AgentBuilder')
