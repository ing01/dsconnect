class Api::V1::ProfilesController < Api::BaseController
  AGENDA_COLOR_FORMAT = /A#h{6}z/

  before_action :set_user

  def show; end

  def update
    return render_could_not_create_error('Cor da agenda inválida') unless valid_agenda_color?

    if password_params[:password].present?
      render_could_not_create_error('Invalid current password') and return unless @user.valid_password?(password_params[:current_password])

      @user.update!(password_params.except(:current_password))
    end

    @user.assign_attributes(profile_params)
    @user.custom_attributes.merge!(custom_attributes_params.to_h.except('agenda_color'))
    assign_agenda_color
    @user.save!
  end

  def avatar
    @user.avatar.attachment.destroy! if @user.avatar.attached?
    @user.reload
  end

  def auto_offline
    @user.account_users.find_by!(account_id: auto_offline_params[:account_id]).update!(auto_offline: auto_offline_params[:auto_offline] || false)
  end

  def availability
    @user.account_users.find_by!(account_id: availability_params[:account_id]).update!(availability: availability_params[:availability])
  end

  def set_active_account
    @user.account_users.find_by(account_id: profile_params[:account_id]).update(active_at: Time.now.utc)
    head :ok
  end

  def resend_confirmation
    @user.send_confirmation_instructions unless @user.confirmed?
    head :ok
  end

  def reset_access_token
    @user.access_token.regenerate_token
    @user.reload
  end

  private

  def set_user
    @user = current_user
  end

  def availability_params
    params.require(:profile).permit(:account_id, :availability)
  end

  def auto_offline_params
    params.require(:profile).permit(:account_id, :auto_offline)
  end

  def profile_params
    params.require(:profile).permit(
      :email,
      :name,
      :display_name,
      :avatar,
      :message_signature,
      :account_id,
      ui_settings: {}
    )
  end

  def custom_attributes_params
    params.require(:profile).permit(:phone_number, :agenda_color)
  end

  # Cor escolhida pela pessoa para os eventos dela na agenda (#rrggbb).
  # Vazio volta para a cor automática.
  def valid_agenda_color?
    color = custom_attributes_params[:agenda_color]
    color.blank? || color.match?(AGENDA_COLOR_FORMAT)
  end

  def assign_agenda_color
    return unless custom_attributes_params.key?(:agenda_color)

    color = custom_attributes_params[:agenda_color]
    if color.blank?
      @user.custom_attributes.delete('agenda_color')
    else
      @user.custom_attributes['agenda_color'] = color.downcase
    end
  end

  def password_params
    params.require(:profile).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end
