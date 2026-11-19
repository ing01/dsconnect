// Funcoes puras da tela "Nichos por agente": nomes a partir dos ids, filtro da busca e o que muda
// ao marcar/desmarcar um item. Sem Vue nem API, para testar sozinhas.

const normalize = text =>
  String(text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

/** Os nomes dos itens (nichos ou sub-nichos) pelos ids, na ordem da lista do agente. */
export const namesFor = (ids = [], items = []) => {
  const byId = new Map(items.map(item => [item.id, item.name]));
  return ids.map(id => byId.get(id)).filter(Boolean);
};

/**
 * Filtra os agentes pelo texto: o nome do agente OU qualquer nicho/sub-nicho dele contem o
 * texto (sem diferenciar maiuscula nem acento). Sem texto, todos.
 */
export const filterAgents = (agents, query, niches, subNiches) => {
  const term = normalize(query);
  if (!term) return agents;

  return agents.filter(agent => {
    const haystack = [
      agent.name,
      ...namesFor(agent.niche_ids, niches),
      ...namesFor(agent.sub_niche_ids, subNiches),
    ];
    return haystack.some(text => normalize(text).includes(term));
  });
};

/** Itens (nichos ou sub-nichos) cujo nome contem o texto da busca do editor. */
export const filterItems = (items, query) => {
  const term = normalize(query);
  return term
    ? items.filter(item => normalize(item.name).includes(term))
    : items;
};

/** Marca ou desmarca um id numa lista de ids, sem repetir e sem mexer na original. */
export const toggleId = (ids, id) =>
  ids.includes(id) ? ids.filter(current => current !== id) : [...ids, id];

/** A lista de ids mudou em relacao ao que estava salvo (ordem nao conta). */
export const sameIds = (a = [], b = []) =>
  a.length === b.length && [...a].sort().join(',') === [...b].sort().join(',');
