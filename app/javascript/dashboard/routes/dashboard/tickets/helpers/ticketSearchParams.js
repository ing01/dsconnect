/**
 * Os parâmetros da Busca detalhada, no formato que a API espera.
 *
 * Vive aqui porque a lista e a exportação precisam ser exatamente os mesmos
 * filtros: se cada uma montasse os seus, o arquivo divergiria da tela no
 * primeiro filtro novo que alguém criasse.
 */

// Uma lista vazia é o mesmo que nenhum filtro, então ela não vai para a URL.
// Com valores, o Rails transforma o array num IN - é o "ou" dentro do filtro.
const list = values => (values?.length ? values : undefined);

/**
 * @param {object} filters estado dos filtros da Busca detalhada
 * @returns {object} parâmetros da requisição, sem paginação
 */
export const toSearchParams = (filters = {}) => ({
  status: list(filters.status),
  // Mesa é escolha única; os Estágios dela é que são vários.
  team_id: filters.teamId || undefined,
  ticket_column_id: list(filters.ticketColumnIds),
  assignee_id: list(filters.assigneeIds),
  company_id: list(filters.companyIds),
  contact_id: list(filters.contactIds),
  priority: list(filters.priority),
  ticket_category_id: list(filters.categoryIds),
  display_id: filters.displayId || undefined,
  title: filters.title || undefined,
  created_after: filters.createdAfter || undefined,
  created_before: filters.createdBefore || undefined,
  // Impedimento e um eixo proprio, ao lado do status: so vai quando pedido, e
  // ausente a listagem se comporta exatamente como sempre.
  blocked: filters.blocked ? true : undefined,
});
