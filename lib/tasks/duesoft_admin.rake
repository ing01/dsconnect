# Creates (or repairs) the administrator used to sign in to an environment that
# was deployed from scratch - homologation, a fresh container, a rebuilt volume.
#
# The credentials come from the environment on purpose. A password written here
# would live in the repository and in its history, readable by anyone who can
# clone it, and rotating it would not remove the old one from the log.
#
#   ADMIN_EMAIL=voce@empresa.com ADMIN_PASSWORD='...' bundle exec rake duesoft:admin
#
# Safe to run repeatedly: an existing user keeps their account membership and
# only has the password reset when one is supplied.
namespace :duesoft do
  desc 'Create or repair the administrator from ADMIN_EMAIL / ADMIN_PASSWORD'
  task admin: :environment do
    email = ENV.fetch('ADMIN_EMAIL', nil)
    password = ENV.fetch('ADMIN_PASSWORD', nil)

    if email.blank?
      puts 'ADMIN_EMAIL nao definido. Nada a fazer.'
      puts "Uso: ADMIN_EMAIL=voce@empresa.com ADMIN_PASSWORD='...' bundle exec rake duesoft:admin"
      next
    end

    account = DueSoft::AdminSetup.account_for(ENV.fetch('ADMIN_ACCOUNT_NAME', 'DueSoft'))
    user = DueSoft::AdminSetup.user_for(email: email, password: password,
                                        name: ENV.fetch('ADMIN_NAME', 'Administrador'))
    DueSoft::AdminSetup.grant_administrator(user: user, account: account)

    puts "conta   : ##{account.id} #{account.name}"
    puts "usuario : ##{user.id} #{user.email} (administrator)"
    puts password.present? ? 'senha   : definida a partir de ADMIN_PASSWORD' : 'senha   : mantida como estava'
  end
end

module DueSoft
  # Kept out of the task body so each step is nameable and testable.
  module AdminSetup
    module_function

    def account_for(name)
      Account.find_by(name: name) || Account.first || Account.create!(name: name)
    end

    def user_for(email:, password:, name:)
      user = User.find_by(email: email)
      return update_existing(user, password) if user

      create_new(email: email, password: password, name: name)
    end

    def update_existing(user, password)
      # Only when a new one was supplied: re-running the task without
      # ADMIN_PASSWORD must not disturb a working login.
      user.update!(password: password, password_confirmation: password) if password.present?
      user
    end

    def create_new(email:, password:, name:)
      raise ArgumentError, 'ADMIN_PASSWORD e obrigatorio para criar um usuario novo' if password.blank?

      user = User.new(name: name, email: email, password: password, password_confirmation: password)
      # There is no one to click a confirmation link on a freshly deployed box.
      user.skip_confirmation!
      user.save!
      user
    end

    def grant_administrator(user:, account:)
      membership = AccountUser.find_or_initialize_by(account_id: account.id, user_id: user.id)
      membership.role = :administrator
      membership.save!
      membership
    end
  end
end
