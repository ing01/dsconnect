// Pure predicate used to decide whether a ticket should be visible under the
// Kanban's client-side filters (filters are applied client-side, over the
// tickets already loaded for the open board).
// `filters.assigneeIds` is a list of already-resolved agent ids; an empty or
// missing list means "every agent", so unassigned tickets stay visible too.
export function ticketMatchesFilters(ticket, filters = {}) {
  if (!filters) return true;

  const { assigneeIds } = filters;
  if (assigneeIds?.length && !assigneeIds.includes(ticket.assignee_id)) {
    return false;
  }
  if (filters.teamId && ticket.team_id !== filters.teamId) {
    return false;
  }
  if (filters.priority && ticket.priority !== filters.priority) {
    return false;
  }
  if (filters.status && ticket.status !== filters.status) {
    return false;
  }
  // Usado pela tela de Sprint ativo (Modulo de Desenvolvimento): o MESMO
  // quadro da Mesa, so' escondendo visualmente quem nao e' deste Sprint -
  // arrastar entre Estagios continua funcionando normalmente, porque a lista
  // por tras do Draggable nao muda de tamanho.
  if (filters.sprintId !== undefined && ticket.sprint_id !== filters.sprintId) {
    return false;
  }
  // Estagio - usado pelo filtro do Backlog/Sprint do Modulo de
  // Desenvolvimento, do mesmo jeito que os demais campos aqui.
  if (filters.columnId && ticket.ticket_column_id !== filters.columnId) {
    return false;
  }
  if (filters.query) {
    const query = filters.query.trim().toLowerCase();
    if (query) {
      const matchesTitle = (ticket.title || '').toLowerCase().includes(query);
      // A leading "#" is how the ticket number is written everywhere in the UI,
      // so both "#12" and "12" are accepted as a number search.
      const matchesDisplayId = String(ticket.display_id || '').includes(
        query.replace(/^#/, '')
      );
      const matchesAssignee = (ticket.assignee_name || '')
        .toLowerCase()
        .includes(query);
      const matchesCompany = (ticket.company_name || '')
        .toLowerCase()
        .includes(query);
      if (
        !matchesTitle &&
        !matchesDisplayId &&
        !matchesAssignee &&
        !matchesCompany
      ) {
        return false;
      }
    }
  }

  return true;
}
