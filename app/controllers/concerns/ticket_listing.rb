# A listagem de tickets: o mesmo endpoint serve a coluna do Kanban e a Busca
# detalhada, que sao paginadas de formas diferentes.
#
# Extraido do TicketsController pelo mesmo motivo que o TicketExporting: a
# classe estava no limite de tamanho, e a acao `index` carregava sozinha as
# duas politicas de paginacao mais a ordenacao.
module TicketListing
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25

  LIST_INCLUDES = [:team, :ticket_column, :ticket_category, :company, :contact,
                   *AssigneeLeveled.assignee_associations,
                   { conversations: :contact }].freeze

  private

  def filtered_tickets
    scope = Current.account.tickets.includes(*LIST_INCLUDES)
    TicketFinder.new(scope: scope, params: params, current_user: Current.user).perform
  end

  # A coluna do Kanban vem inteira, sem paginacao: o arrastar-e-soltar depende
  # de ter todos os cartoes em maos, e a ordem e a posicao dentro da coluna.
  def load_kanban_column(relation)
    @tickets = relation.order(:position)
    @tickets_count = @tickets.count
    @current_page = 1
  end

  # Qualquer outra listagem e paginada, e a ordem sai dos cabecalhos da Busca
  # detalhada. Sem parametro, segue a de sempre: mais recentes primeiro.
  #
  # `support_queue` e a fila da triagem automatica (nivel do cliente, depois
  # prioridade) - uma ordenacao composta, por isso fora do modelo de "uma
  # coluna" do `Tickets::SearchOrdering`.
  def load_paginated_list(relation)
    ordered = if params[:sort_by].to_s == 'support_queue'
                relation.support_queue_order
              else
                Tickets::SearchOrdering.apply(relation, sort_by: params[:sort_by], sort_order: params[:sort_order])
              end
    @tickets_count = ordered.count
    @current_page = (params[:page] || 1).to_i
    @tickets = ordered.page(@current_page).per(params[:per_page] || DEFAULT_PER_PAGE)
  end
end
