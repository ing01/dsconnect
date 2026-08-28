class Api::V1::Accounts::ProjectModulesController < Api::V1::Accounts::BaseController
  before_action :fetch_project_module, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @project_modules = Current.account.project_modules.includes(project_module_task_templates: :project_task_template).ordered
  end

  def show; end

  def create
    @project_module = Current.account.project_modules.new(project_module_params)
    ActiveRecord::Base.transaction do
      @project_module.save!
      sync_task_templates!
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @project_module.update!(project_module_params)
      sync_task_templates! if params[:task_template_ids].present? || params[:task_templates].present?
    end
    render 'show'
  end

  def destroy
    @project_module.destroy!
    head :ok
  end

  private

  def fetch_project_module
    @project_module = Current.account.project_modules.find(params[:id])
  end

  def project_module_params
    params.require(:project_module).permit(:name, :description)
  end

  def sync_task_templates!
    if params[:task_templates].present?
      @project_module.project_module_task_templates.destroy_all
      params[:task_templates].each_with_index do |item, index|
        template_id = item.is_a?(Hash) ? item[:id] || item[:task_template_id] : item
        next if template_id.blank?

        @project_module.project_module_task_templates.create!(
          project_task_template_id: template_id,
          position: index
        )
      end
    elsif params[:task_template_ids].present?
      @project_module.project_module_task_templates.destroy_all
      params[:task_template_ids].each_with_index do |template_id, index|
        next if template_id.blank?

        @project_module.project_module_task_templates.create!(
          project_task_template_id: template_id,
          position: index
        )
      end
    end
  end
end
