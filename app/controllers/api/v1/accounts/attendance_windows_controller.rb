# Configuracao de Atendimento: os periodos (dia da semana + horario) em que a
# triagem automatica pode comecar - ver Account#within_attendance_hours? e
# AutomationRules::Flow::DispatcherService.
class Api::V1::Accounts::AttendanceWindowsController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Current.account, :update?) }

  def index
    @attendance_windows = current_windows
  end

  # Substitui o conjunto inteiro de uma vez - mais simples e menos propenso a
  # erro do que casar id-a-id quando qualquer periodo pode ter sido
  # adicionado, removido ou trocado de dia na mesma edicao da tela.
  def bulk_update
    ActiveRecord::Base.transaction do
      Current.account.attendance_windows.destroy_all
      windows_params.each { |window| Current.account.attendance_windows.create!(window) }
    end
    @attendance_windows = current_windows
    render :index
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
  end

  private

  def current_windows
    Current.account.attendance_windows.order(:day_of_week, :start_minute)
  end

  def windows_params
    (params[:attendance_windows] || []).map { |window| window.permit(:day_of_week, :start_minute, :end_minute) }
  end
end
