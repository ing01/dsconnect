class Api::V1::Accounts::BulkActionsController < Api::V1::Accounts::BaseController
  def create
    case normalized_type
    when 'Conversation'
      return reject_out_of_order_assign if blocked_conversation_assign?

      enqueue_conversation_job
      head :ok
    when 'Contact'
      check_authorization_for_contact_action
      enqueue_contact_job
      head :ok
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  def normalized_type
    params[:type].to_s.camelize
  end

  def enqueue_conversation_job
    ::BulkActionsJob.perform_later(
      account: @current_account,
      user: current_user,
      params: conversation_params
    )
  end

  # Mesma trava de Api::V1::Accounts::Conversations::AssignmentsController#blocked_manual_assign?,
  # so que checada de forma SINCRONA, antes de enfileirar o job - isto roda
  # em background (ver BulkActionsJob#conversation_update_params), entao um
  # 422 aqui e o unico jeito do atendente receber um erro de verdade em vez
  # de um "sucesso" fantasma pra uma atribuicao que nunca aconteceu.
  def blocked_conversation_assign?
    assignee_id = params.dig(:fields, :assignee_id)
    return false if assignee_id.blank?
    return false if Current.account_user&.administrator?

    target_conversations.where.not(queue_id: nil).exists?
  end

  def target_conversations
    Conversation.where(account_id: @current_account.id, display_id: params[:ids])
  end

  def reject_out_of_order_assign
    render json: { error: I18n.t('errors.queues.out_of_order_assignment') }, status: :unprocessable_entity
  end

  def enqueue_contact_job
    Contacts::BulkActionJob.perform_later(
      @current_account.id,
      current_user.id,
      contact_params
    )
  end

  def delete_contact_action?
    params[:action_name] == 'delete'
  end

  def check_authorization_for_contact_action
    authorize(Contact, :destroy?) if delete_contact_action?
  end

  def conversation_params
    # TODO: Align conversation payloads with the `{ action_name, action_attributes }`
    # and then remove this method in favor of a common params method.
    base = params.permit(
      :snoozed_until,
      fields: [:status, :assignee_id, :team_id]
    )
    append_common_bulk_attributes(base)
  end

  def contact_params
    # TODO: remove this method in favor of a common params method.
    # once legacy conversation payloads are migrated.
    append_common_bulk_attributes({})
  end

  def append_common_bulk_attributes(base_params)
    # NOTE: Conversation payloads historically diverged per action. Going forward we
    # want all objects to share a common contract: `{ action_name, action_attributes }`
    common = params.permit(:type, :action_name, ids: [], labels: [add: [], remove: []])
    base_params.merge(common)
  end
end
