class BulkActionsJob < ApplicationJob
  include DateRangeHelper

  queue_as :medium
  attr_accessor :records

  MODEL_TYPE = ['Conversation'].freeze

  def perform(account:, params:, user:)
    @account = account
    @user = user
    Current.user = user
    @params = params
    @records = records_to_updated(params[:ids])
    bulk_update
  ensure
    Current.reset
  end

  def bulk_update
    bulk_remove_labels
    bulk_conversation_update
  end

  def bulk_conversation_update
    params = available_params(@params)
    records.each do |conversation|
      bulk_add_labels(conversation)
      bulk_snoozed_until(conversation)
      conversation.update(conversation_update_params(params, conversation)) if params
    end
  end

  # Mesma trava do endpoint de atribuicao individual
  # (Api::V1::Accounts::Conversations::AssignmentsController#blocked_manual_assign?)
  # - quem NAO E Administrador nao atribui livremente uma conversa numa fila,
  # nem em lote nem pelo menu de contexto (os dois caem aqui). So remove o
  # campo `assignee_id` da atualizacao desta conversa; as outras mudancas do
  # lote (status, time, labels) continuam valendo normalmente.
  def conversation_update_params(params, conversation)
    return params unless params['assignee_id'] || params[:assignee_id]
    return params if administrator?
    return params if conversation.queue_id.blank?

    params.except('assignee_id', :assignee_id)
  end

  def administrator?
    return @administrator if defined?(@administrator)

    @administrator = @user.account_users.find_by(account_id: @account.id)&.administrator? || false
  end

  def bulk_remove_labels
    records.each do |conversation|
      remove_labels(conversation)
    end
  end

  def available_params(params)
    return unless params[:fields]

    params[:fields].delete_if { |key, value| value.nil? && key == 'status' }
  end

  def bulk_add_labels(conversation)
    conversation.add_labels(@params[:labels][:add]) if @params[:labels] && @params[:labels][:add]
  end

  def bulk_snoozed_until(conversation)
    conversation.snoozed_until = parse_date_time(@params[:snoozed_until].to_s) if @params[:snoozed_until]
  end

  def remove_labels(conversation)
    return unless @params[:labels] && @params[:labels][:remove]

    labels = conversation.label_list - @params[:labels][:remove]
    conversation.update(label_list: labels)
  end

  def records_to_updated(ids)
    current_model = @params[:type].camelcase
    return unless MODEL_TYPE.include?(current_model)

    scope = current_model.constantize.where(account_id: @account.id, display_id: ids)
    Conversations::PermissionFilterService.new(scope, @user, @account).perform
  end
end
