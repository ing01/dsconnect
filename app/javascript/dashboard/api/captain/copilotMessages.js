/* global axios */
import ApiClient from '../ApiClient';

class CopilotMessages extends ApiClient {
  constructor() {
    super('captain/copilot_threads', { accountScoped: true });
  }

  get(threadId) {
    return axios.get(`${this.url}/${threadId}/copilot_messages`);
  }

  create({ threadId, ...rest }) {
    return axios.post(`${this.url}/${threadId}/copilot_messages`, rest);
  }

  // O agente avalia uma resposta do DueBot (rating: positive | negative). Avaliar de
  // novo atualiza a avaliacao anterior; o servidor devolve a mensagem com o feedback.
  rate({ threadId, messageId, rating, reason, comment }) {
    return axios.post(
      `${this.url}/${threadId}/copilot_messages/${messageId}/feedback`,
      { rating, reason, comment }
    );
  }

  clearRating({ threadId, messageId }) {
    return axios.delete(
      `${this.url}/${threadId}/copilot_messages/${messageId}/feedback`
    );
  }
}

export default new CopilotMessages();
