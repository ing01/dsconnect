/* global axios */
import ApiClient from './ApiClient';

// Os Nichos e Sub-nichos de empresa que cada agente (analista) atende.
class AgentNichesAPI extends ApiClient {
  constructor() {
    super('agent_niches', { accountScoped: true });
  }

  // { agents: [{ id, name, email, niche_ids, sub_niche_ids }], niches: [...], sub_niches: [...] }
  list() {
    return axios.get(this.url);
  }

  // Troca a lista do agente (`id` e' o id do usuario). Cada lista so' muda se for enviada.
  save(agentId, { nicheIds, subNicheIds }) {
    return axios.put(`${this.url}/${agentId}`, {
      niche_ids: nicheIds,
      sub_niche_ids: subNicheIds,
    });
  }
}

export default new AgentNichesAPI();
