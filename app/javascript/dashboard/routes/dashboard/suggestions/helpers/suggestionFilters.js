// Predicado puro usado pelos filtros do quadro de Sugestões (filtros rodam
// client-side, sobre a lista já carregada) - mesmo espírito do
// `ticketMatchesFilters` do Kanban de Tickets.
export function suggestionMatchesFilters(suggestion, filters = {}) {
  if (!filters) return true;

  const { priorityId, categoryId, assigneeId, dateFrom, dateTo } = filters;

  if (priorityId && String(suggestion.priority_id) !== String(priorityId)) {
    return false;
  }
  if (categoryId && String(suggestion.category_id) !== String(categoryId)) {
    return false;
  }
  if (assigneeId && String(suggestion.assignee_id) !== String(assigneeId)) {
    return false;
  }
  if (dateFrom || dateTo) {
    // `created_at` chega como ISO datetime - compara só a data (10 primeiros
    // caracteres) contra os inputs `type="date"` (yyyy-mm-dd).
    const createdDate = (suggestion.created_at || '').slice(0, 10);
    if (!createdDate) return false;
    if (dateFrom && createdDate < dateFrom) return false;
    if (dateTo && createdDate > dateTo) return false;
  }

  return true;
}
