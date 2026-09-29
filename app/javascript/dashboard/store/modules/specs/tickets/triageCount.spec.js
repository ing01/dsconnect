import { actions, getters, mutations } from '../../tickets';
import types from '../../../mutation-types';
import TicketsAPI from 'dashboard/api/tickets';

// O contador da Triagem. Ele aparece no menu lateral de toda tela, entao existe
// para dizer que tem chamado esperando SEM que ninguem abra a fila.
vi.mock('dashboard/api/tickets', () => ({
  default: { triageCount: vi.fn() },
}));

const estado = () => ({ triageCount: 0 });

// `mockReset: true` na configuracao do Vitest ja limpa os mocks entre exemplos.
describe('o contador da Triagem', () => {
  it('reads the number from the server', async () => {
    TicketsAPI.triageCount.mockResolvedValue({ data: { count: 3 } });
    const commit = vi.fn();

    await actions.fetchTriageCount({ commit });

    expect(commit).toHaveBeenCalledWith(types.SET_TICKET_TRIAGE_COUNT, 3);
  });

  // Um numero e o que o menu lateral desenha. Uma resposta estranha nao pode
  // virar "NaN" no lugar do contador.
  it('keeps it a number whatever arrives', () => {
    const _state = estado();

    mutations[types.SET_TICKET_TRIAGE_COUNT](_state, undefined);
    expect(_state.triageCount).toBe(0);

    mutations[types.SET_TICKET_TRIAGE_COUNT](_state, '5');
    expect(_state.triageCount).toBe(5);
  });

  it('exposes it to the sidebar', () => {
    expect(getters.getTriageCount({ triageCount: 2 })).toBe(2);
  });

  // Nao engole a falha silenciosamente no store: quem chama decide. O que ela
  // NAO pode fazer e zerar o contador - um zero que ninguem conferiu diria que a
  // fila esvaziou.
  it('leaves the previous number alone when the request fails', async () => {
    TicketsAPI.triageCount.mockImplementation(async () => {
      throw new Error('rede');
    });
    const commit = vi.fn();

    let erro = null;
    try {
      await actions.fetchTriageCount({ commit });
    } catch (e) {
      erro = e;
    }

    expect(erro?.message).toBe('rede');
    expect(commit).not.toHaveBeenCalled();
  });
});
