# Rascunho de ticket por IA: recebe texto livre OU audio, devolve
# categoria/titulo/descricao sugeridos - nunca cria o ticket. A abertura de
# verdade continua em TicketsController#create, com o rascunho so preenchendo
# o mesmo formulario que o cliente revisa e confirma.
class Api::V1::Client::TicketDraftsController < Api::V1::Client::BaseController
  # A tela consulta isto para decidir se mostra a opcao "Abrir com IA" - sem
  # credencial configurada (Hook da conta ou InstallationConfig), a opcao nem
  # aparece, em vez de oferecer algo que vai falhar.
  def enabled
    render json: { enabled: ai_available? }
  end

  def create
    text = resolved_text
    return render json: { error: 'empty_input' }, status: :unprocessable_entity if text.blank?

    categories = client_categories
    return render json: { error: 'no_categories' }, status: :unprocessable_entity if categories.empty?

    result = Captain::TicketDraftService.new(account: Current.account, categories: categories, text: text).perform
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    render json: result
  end

  private

  # Mesmo escopo de `TicketsController#client_teams`/`CategoriesController` -
  # so as Categorias das Mesas marcadas para aparecer no Portal, visiveis ao
  # cliente.
  def client_categories
    TicketCategory.client_visible
                  .joins(:team)
                  .where(teams: { account_id: Current.account.id, active: true, visible_in_portal: true })
                  .order(:position, :id)
                  .to_a
  end

  # Texto digitado tem prioridade; sem ele, transcreve o audio enviado.
  def resolved_text
    return params[:text].to_s.strip if params[:text].present?
    return nil if params[:audio].blank?

    transcription = Captain::AudioTranscriptionService.new(account: Current.account, file: params[:audio]).perform
    transcription[:text]
  end

  def ai_available?
    Current.account.hooks.exists?(app_id: 'openai', status: 'enabled') ||
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.present?
  end
end
