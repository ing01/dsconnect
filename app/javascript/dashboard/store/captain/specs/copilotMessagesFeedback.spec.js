import copilotMessages from '../copilotMessages';
import CopilotMessagesAPI from 'dashboard/api/captain/copilotMessages';

// A resposta da API e' a mensagem inteira, ja com o feedback da pessoa: o store troca
// o registro e a tela mostra o polegar marcado.
vi.mock('dashboard/api/captain/copilotMessages', () => ({
  default: { rate: vi.fn(), clearRating: vi.fn() },
}));

const actions = copilotMessages.actions;
// O nome da mutacao e' gerado pela fabrica do store; descobre-se dele em vez de fixar.
const UPSERT = Object.keys(copilotMessages.mutations).find(name =>
  name.startsWith('UPSERT')
);

describe('copilotMessages, feedback', () => {
  it('avaliar manda a avaliacao e troca o registro pela resposta do servidor', async () => {
    const mensagem = { id: 7, feedback: { rating: 'positive' } };
    CopilotMessagesAPI.rate.mockResolvedValue({ data: mensagem });
    const commit = vi.fn();
    const payload = { threadId: 3, messageId: 7, rating: 'positive' };

    await actions.rate({ commit }, payload);

    expect(CopilotMessagesAPI.rate).toHaveBeenCalledWith(payload);
    expect(commit).toHaveBeenCalledWith(UPSERT, mensagem);
  });

  it('desfazer a avaliacao troca o registro pela mensagem sem feedback', async () => {
    const mensagem = { id: 7, feedback: null };
    CopilotMessagesAPI.clearRating.mockResolvedValue({ data: mensagem });
    const commit = vi.fn();

    await actions.clearRating({ commit }, { threadId: 3, messageId: 7 });

    expect(CopilotMessagesAPI.clearRating).toHaveBeenCalledWith({
      threadId: 3,
      messageId: 7,
    });
    expect(commit).toHaveBeenCalledWith(UPSERT, mensagem);
  });
});
