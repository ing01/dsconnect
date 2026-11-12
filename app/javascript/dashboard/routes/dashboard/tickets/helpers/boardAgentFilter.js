import { LocalStorage } from 'shared/helpers/localStorage';

// O filtro de agente do Kanban e' trabalho de quem esta na tela: trocar de aba (Chat interno,
// por exemplo) desmonta o modulo de Tickets e, sem isto, o filtro voltava vazio. Fica guardado
// por conta e por Mesa - a mesma chave da ordenacao -, no navegador.
const FILTER_KEY_PREFIX = 'ticket-kanban-agent-filter';

const filterStorageKey = (accountId, teamId) =>
  `${FILTER_KEY_PREFIX}::${accountId}::${teamId}`;

/**
 * Os agentes que estavam filtrados nesta Mesa.
 * @param {number} accountId conta
 * @param {number} teamId Mesa
 * @returns {number[]} ids dos agentes (vazio = todos)
 */
export const readAgentFilter = (accountId, teamId) => {
  const stored = LocalStorage.get(filterStorageKey(accountId, teamId));
  if (!Array.isArray(stored)) return [];

  return stored.map(Number).filter(id => Number.isInteger(id) && id > 0);
};

/**
 * Guarda os agentes filtrados nesta Mesa; lista vazia apaga o registro.
 * @param {number} accountId conta
 * @param {number} teamId Mesa
 * @param {number[]} agentIds ids dos agentes filtrados
 */
export const writeAgentFilter = (accountId, teamId, agentIds) => {
  const key = filterStorageKey(accountId, teamId);
  if (agentIds?.length) LocalStorage.set(key, agentIds);
  else LocalStorage.remove(key);
};

/**
 * Tira do filtro quem nao esta mais na Mesa (agente removido do time): um filtro preso a um
 * id que nao aparece na linha de avatares esconderia todos os tickets sem como desfazer.
 * @param {number[]} agentIds filtro atual
 * @param {{id: number}[]} members membros da Mesa
 * @returns {number[]} so os que ainda sao membros
 */
export const keepCurrentMembers = (agentIds, members) =>
  agentIds.filter(id => members.some(member => member.id === id));
