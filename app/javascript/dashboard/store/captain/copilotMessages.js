import CopilotMessagesAPI from 'dashboard/api/captain/copilotMessages';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CopilotMessages',
  API: CopilotMessagesAPI,
  getters: {
    getMessagesByThreadId: state => copilotThreadId => {
      return state.records
        .filter(record => record.copilot_thread?.id === Number(copilotThreadId))
        .sort((a, b) => a.id - b.id);
    },
  },
  actions: mutationTypes => ({
    upsert({ commit }, data) {
      commit(mutationTypes.UPSERT, data);
    },
    // A resposta da API e a mensagem inteira, ja com o feedback desta pessoa:
    // o UPSERT troca o registro e a tela mostra o polegar marcado.
    async rate({ commit }, payload) {
      const response = await CopilotMessagesAPI.rate(payload);
      commit(mutationTypes.UPSERT, response.data);
    },
    async clearRating({ commit }, payload) {
      const response = await CopilotMessagesAPI.clearRating(payload);
      commit(mutationTypes.UPSERT, response.data);
    },
  }),
});
