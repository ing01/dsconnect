# Rascunho de ticket por IA a partir da conversa - o "Abrir ticket
# automaticamente" que o atendente aciona manualmente, nunca sozinho.
#
# Existe porque uma conversa comecada pelo atendente (`agent_initiated`), como
# o chat do Portal do Cliente, nao passa pelo fluxo de automacao (a automacao
# so comeca sozinha quando quem fala primeiro e' o cliente) - sem este botao,
# o atendente teria que preencher o formulario de ticket do zero, mesmo tendo
# acabado de escrever a conversa inteira que ja diz do que se trata.
#
# So devolve o RASCUNHO (Mesa/Categoria/titulo/descricao) - quem cria de
# verdade continua sendo o mesmo formulario de sempre
# (`tickets/createTicketWithContext`), que o atendente ve preenchido e pode
# ajustar antes de confirmar.
class Api::V1::Accounts::Conversations::TicketDraftsController < Api::V1::Accounts::Conversations::BaseController
  def create
    return render json: { error: 'empty_conversation' }, status: :unprocessable_entity if transcript.blank?

    categories = account_categories
    return render json: { error: 'no_categories' }, status: :unprocessable_entity if categories.empty?

    result = Captain::TicketDraftService.new(account: Current.account, categories: categories, text: transcript).perform
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    render json: result.merge(team_id: team_id_for(result[:ticket_category_id]))
  end

  private

  # Todas as Categorias de Mesas ativas da conta - ao contrario do rascunho do
  # Portal, aqui quem pergunta e' quem atende, e enxerga tudo que a conta tem,
  # nao so o que o Portal expoe ao cliente.
  def account_categories
    TicketCategory.joins(:team)
                  .where(teams: { account_id: Current.account.id, active: true })
                  .order(:position, :id)
                  .to_a
  end

  def team_id_for(category_id)
    return if category_id.blank?

    account_categories.find { |category| category.id == category_id }&.team_id
  end

  # A conversa inteira, na ordem em que aconteceu - e' o "contexto da
  # conversa" que a IA le para sugerir Mesa/Categoria/titulo/descricao.
  def transcript
    @transcript ||= @conversation.messages.chat.order(created_at: :asc).filter_map do |message|
      next if message.content.blank?

      "#{transcript_author(message)}: #{message.content}"
    end.join("\n")
  end

  def transcript_author(message)
    return 'Cliente' if message.sender_type == 'Contact'

    message.sender_type == 'User' ? (message.sender&.name || 'Atendente') : 'Sistema'
  end
end
