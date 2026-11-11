# O cronometro de apontamento de um ticket. Cada pessoa mexe so nos seus: a busca e'
# sempre dentro dos cronometros de quem esta logado, entao o de outro agente nao
# existe para ela (404).
class Api::V1::Accounts::TicketTimersController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_timer, only: [:pause, :resume, :finish, :destroy]
  before_action :check_authorization

  def index
    @ticket_timers = my_timers.to_a
  end

  # Iniciar. Se ja ha um cronometro desta pessoa neste ticket, devolve ele (retoma se
  # estava pausado) em vez de criar outro: clicar duas vezes nao duplica.
  def create
    @ticket_timer = my_timers.first&.resume! || TicketTimer.start!(
      ticket: @ticket, user: Current.user, category: params[:category], note: params[:note]
    )
    render 'show'
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def pause
    @ticket_timer.pause!
    render 'show'
  end

  def resume
    @ticket_timer.resume!
    render 'show'
  end

  # Finalizar: o tempo vira um apontamento comum, que devolvo para a tela listar.
  def finish
    @ticket_time_entry = @ticket_timer.finish!
    render 'api/v1/accounts/ticket_time_entries/show'
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Descartar: apaga o cronometro sem lancar nada.
  def destroy
    @ticket_timer.destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def my_timers
    @ticket.ticket_timers.where(user_id: Current.user.id)
  end

  def fetch_timer
    @ticket_timer = my_timers.find(params[:id])
  end
end
