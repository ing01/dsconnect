/**
 * Os filtros da lista de chamados do cliente (Mesa, Estágio, Responsável,
 * status e período de abertura) - o que a tela guarda, conta e mostra como chip.
 * Quem aplica é o servidor; aqui só se descreve.
 */

export const emptyFilters = () => ({
  teamId: null,
  ticketColumnId: null,
  assigneeId: null,
  status: null,
  createdAfter: null,
  createdBefore: null,
});

const isFilled = value => value !== null && value !== undefined && value !== '';

export const countActive = filters => Object.values(filters).filter(isFilled).length;

// Tirar a Mesa tira o Estágio junto: um Estágio de outra Mesa não faz sentido, e
// o servidor ainda o aplicaria sozinho.
export const withoutFilter = (filters, key) => ({
  ...filters,
  [key]: null,
  ...(key === 'teamId' ? { ticketColumnId: null } : {}),
});

const nameOf = (list, id) => list.find(item => item.id === id)?.name;

// "2026-10-01" -> data local. Sem o horário, `new Date('2026-10-01')` é lido
// como UTC e, no Brasil, mostraria o dia anterior.
const formatDate = value => new Date(`${value}T00:00:00`).toLocaleDateString();

/**
 * Uma entrada por filtro ativo, na ordem em que aparecem no modal:
 * `{ key, label }`, com `key` sendo o campo de `filters` que o chip remove.
 */
export const describeActive = (
  filters,
  { teams = [], ticketColumns = [], assignees = [] },
  t
) => {
  const chips = [];
  const add = (key, title, value) => {
    if (isFilled(filters[key]) && value) {
      chips.push({ key, label: `${title}: ${value}` });
    }
  };

  add('teamId', t('CLIENT_AREA.BOARD.FILTERS.TEAM'), nameOf(teams, filters.teamId));
  add(
    'ticketColumnId',
    t('CLIENT_AREA.BOARD.FILTERS.COLUMN'),
    nameOf(ticketColumns, filters.ticketColumnId)
  );
  add(
    'assigneeId',
    t('CLIENT_AREA.BOARD.FILTERS.ASSIGNEE'),
    nameOf(assignees, filters.assigneeId)
  );
  add(
    'status',
    t('CLIENT_AREA.BOARD.STATUS'),
    filters.status && t(`TICKET.STATUS.${filters.status.toUpperCase()}`)
  );
  add(
    'createdAfter',
    t('CLIENT_AREA.BOARD.FILTERS.OPENED_FROM'),
    filters.createdAfter && formatDate(filters.createdAfter)
  );
  add(
    'createdBefore',
    t('CLIENT_AREA.BOARD.FILTERS.OPENED_UNTIL'),
    filters.createdBefore && formatDate(filters.createdBefore)
  );

  return chips;
};
