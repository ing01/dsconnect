import { LocalStorage } from 'shared/helpers/localStorage';

// Which Estagios a user has collapsed is a per-viewer view preference, not a
// property of the Mesa, so it lives in localStorage rather than the API.
// One entry per (account, Mesa) keeps the state independent between Mesas;
// storing column ids (not indexes) keeps it stable across renames/reorders.
export const COLLAPSED_COLUMNS_KEY_PREFIX = 'ticket-kanban-collapsed-columns';

// `scope` separa preferencias que falam dos MESMOS Estagios em telas
// diferentes: recolher um grupo na lista nao pode recolher a coluna no Kanban,
// que e outra forma de ler. Sem scope a chave fica como sempre foi, para o
// Kanban nao perder o que os usuarios ja tinham guardado.
export const collapsedColumnsKey = (accountId, teamId, scope = null) =>
  scope
    ? `${COLLAPSED_COLUMNS_KEY_PREFIX}::${scope}::${accountId}::${teamId}`
    : `${COLLAPSED_COLUMNS_KEY_PREFIX}::${accountId}::${teamId}`;

export const readCollapsedColumnIds = (
  accountId,
  teamId,
  validIds = null,
  scope = null
) => {
  const stored = LocalStorage.get(
    collapsedColumnsKey(accountId, teamId, scope)
  );
  const ids = Array.isArray(stored)
    ? stored.map(Number).filter(Number.isFinite)
    : [];

  // Drops ids of Estagios that no longer exist, so a deleted column can't keep
  // resurrecting as collapsed state.
  return validIds ? ids.filter(id => validIds.includes(id)) : ids;
};

export const writeCollapsedColumnIds = (accountId, teamId, ids, scope = null) =>
  LocalStorage.set(collapsedColumnsKey(accountId, teamId, scope), [
    ...new Set(ids.map(Number)),
  ]);

export const toggleCollapsedColumn = (
  accountId,
  teamId,
  columnId,
  scope = null
) => {
  const id = Number(columnId);
  const current = readCollapsedColumnIds(accountId, teamId, null, scope);
  const next = current.includes(id)
    ? current.filter(storedId => storedId !== id)
    : [...current, id];

  writeCollapsedColumnIds(accountId, teamId, next, scope);
  return next;
};
