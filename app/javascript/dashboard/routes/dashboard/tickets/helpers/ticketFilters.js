// Pure predicate used to decide whether a ticket should be visible under the
// Kanban's client-side filters (see plan section E: filters are applied
// client-side for MVP, over tickets already loaded for the open board).
// `filters.assigneeId` is expected to already be resolved (e.g. "Meus
// tickets" is resolved to the current user's id by the caller), so this
// helper only ever compares plain values.
export function ticketMatchesFilters(ticket, filters = {}) {
  if (!filters) return true;

  if (filters.assigneeId && ticket.assignee_id !== filters.assigneeId) {
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
  if (filters.query) {
    const query = filters.query.trim().toLowerCase();
    if (query) {
      const matchesTitle = (ticket.title || '').toLowerCase().includes(query);
      const matchesDisplayId = String(ticket.display_id || '').includes(
        query
      );
      if (!matchesTitle && !matchesDisplayId) return false;
    }
  }

  return true;
}
