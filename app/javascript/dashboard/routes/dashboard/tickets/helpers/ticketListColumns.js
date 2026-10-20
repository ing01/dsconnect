import { LocalStorage } from 'shared/helpers/localStorage';

// Largura e colunas ocultas da lista de tickets sao preferencia de quem olha
// (um agente, ou o cliente no Portal), entao vivem no localStorage - nao faz
// sentido isso ser por conta inteira em vez de por navegador/pessoa, mas
// tambem nao faz sentido perder a escolha ao trocar de tela, entao a chave e
// so por conta, compartilhada entre a lista interna ("Busca detalhada") e a
// do Portal do Cliente - as duas usam as mesmas colunas (TicketListView).
export const TICKET_LIST_COLUMNS_KEY_PREFIX = 'ticket-list-columns';

export const ticketListColumnsKey = accountId =>
  `${TICKET_LIST_COLUMNS_KEY_PREFIX}::${accountId}`;

const emptyPreferences = () => ({ hidden: [], widths: {} });

// `validKeys` limpa coluna que nao existe mais (ex: uma versao antiga
// escondeu uma coluna que foi removida/renomeada desde entao).
export const readColumnPreferences = (accountId, validKeys = null) => {
  const stored = LocalStorage.get(ticketListColumnsKey(accountId));
  if (!stored || typeof stored !== 'object') return emptyPreferences();

  const hidden = Array.isArray(stored.hidden) ? stored.hidden : [];
  const widths =
    stored.widths && typeof stored.widths === 'object' ? stored.widths : {};

  return {
    hidden: validKeys ? hidden.filter(key => validKeys.includes(key)) : hidden,
    widths,
  };
};

export const writeColumnPreferences = (accountId, preferences) =>
  LocalStorage.set(ticketListColumnsKey(accountId), preferences);

export const toggleColumnHidden = (accountId, columnKey, validKeys = null) => {
  const current = readColumnPreferences(accountId, validKeys);
  const hidden = current.hidden.includes(columnKey)
    ? current.hidden.filter(key => key !== columnKey)
    : [...current.hidden, columnKey];

  const next = { ...current, hidden };
  writeColumnPreferences(accountId, next);
  return next;
};

export const setColumnWidth = (
  accountId,
  columnKey,
  width,
  validKeys = null
) => {
  const current = readColumnPreferences(accountId, validKeys);
  const next = {
    ...current,
    widths: { ...current.widths, [columnKey]: width },
  };
  writeColumnPreferences(accountId, next);
  return next;
};
