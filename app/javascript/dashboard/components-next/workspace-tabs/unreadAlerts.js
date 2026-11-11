// O aviso "!" de mensagem nao lida: de que tipo e' cada tela e como o titulo da aba do
// navegador o mostra. Sem estado: so' regras, para as abas, o menu e o navegador
// usarem a mesma.

export const ALERT_KIND = Object.freeze({
  CONVERSATIONS: 'conversations',
  INTERNAL_CHAT: 'internal_chat',
});

// Nomes das rotas das telas de conversa (a lista e as visoes por caixa, time,
// marcador, pasta...). Uma aba de qualquer uma delas avisa quando ha conversa
// minha com mensagem nao lida.
const CONVERSATION_ROUTES = new Set([
  'home',
  'inbox_conversation',
  'inbox_dashboard',
  'label_conversations',
  'team_conversations',
  'folder_conversations',
  'conversation_mentions',
  'conversation_unattended',
  'email_conversations',
  'conversation_participating',
]);

const INTERNAL_CHAT_ROUTES = new Set(['internal_chat']);

/**
 * Que tipo de aviso uma aba (ou item de menu) carrega.
 * @param {string} routeName nome da rota da tela
 * @returns {string|null} 'conversations', 'internal_chat' ou null (sem aviso)
 */
export const alertKindForRoute = routeName => {
  if (CONVERSATION_ROUTES.has(routeName)) return ALERT_KIND.CONVERSATIONS;
  if (INTERNAL_CHAT_ROUTES.has(routeName)) return ALERT_KIND.INTERNAL_CHAT;
  return null;
};

/**
 * A chave de uma aba de tela e' `nome_da_rota|parametros` (ver `entryKey`).
 * @param {string} tabKey chave da aba
 * @returns {string|null} o tipo de aviso da aba
 */
export const alertKindForTabKey = tabKey =>
  alertKindForRoute(String(tabKey || '').split('|')[0]);

/**
 * Esta aba deve mostrar o "!" agora?
 * @param {string} tabKey chave da aba
 * @param {{conversations: boolean, internalChat: boolean}} alerts o que esta com aviso
 * @returns {boolean} true quando a tela tem mensagem nao lida para a pessoa
 */
export const tabHasAlert = (tabKey, alerts) => {
  const kind = alertKindForTabKey(tabKey);
  if (kind === ALERT_KIND.CONVERSATIONS) return !!alerts.conversations;
  if (kind === ALERT_KIND.INTERNAL_CHAT) return !!alerts.internalChat;
  return false;
};

export const TITLE_ALERT_PREFIX = '(!) ';

/**
 * O titulo da aba do navegador com (ou sem) o aviso, sem acumular prefixos.
 * @param {string} title titulo atual
 * @param {boolean} alert se ha aviso
 * @returns {string} titulo com `(!) ` no inicio quando ha aviso
 */
export const withTitleAlert = (title, alert) => {
  const bare = String(title || '').startsWith(TITLE_ALERT_PREFIX)
    ? title.slice(TITLE_ALERT_PREFIX.length)
    : String(title || '');
  return alert ? `${TITLE_ALERT_PREFIX}${bare}` : bare;
};
