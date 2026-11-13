import { flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { useBacklog } from '../useBacklog';

// Arrastar um ticket para um Sprint nao pode "recarregar a tela": o carregando
// (state.isLoading) troca os baldes por um spinner e fecha os que estavam abertos.
const { api } = vi.hoisted(() => ({
  api: { get: vi.fn(), update: vi.fn() },
}));

vi.mock('dashboard/api/tickets', () => ({ default: api }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: [] }),
  useStore: () => ({
    dispatch: vi.fn(() => Promise.resolve()),
    getters: {
      'ticketColumns/getSprints': () => [{ id: 1 }, { id: 2 }],
      'ticketColumns/getBoard': () => null,
      'ticketColumns/getColumns': () => [],
      'teamMembers/getTeamMembers': () => [],
    },
  }),
}));

const montar = async () => {
  api.get.mockResolvedValue({ data: { payload: [] } });
  const backlog = useBacklog();
  backlog.selectTeam(5);
  await flushPromises();

  backlog.state.backlogTickets = [{ id: 9, title: 'A', sprint_id: null }];
  backlog.state.ticketsBySprint = { 1: [], 2: [] };
  api.get.mockClear();
  api.update.mockClear();
  useAlert.mockClear();
  return backlog;
};

describe('useBacklog > moveTicketToSprint', () => {
  it('dando certo, nao recarrega os baldes nem liga o carregando', async () => {
    const backlog = await montar();
    const carregando = [];
    api.update.mockImplementation(() => {
      carregando.push(backlog.state.isLoading);
      return Promise.resolve({});
    });

    await backlog.moveTicketToSprint(9, 1);

    expect(api.update).toHaveBeenCalledWith(9, { ticket: { sprint_id: 1 } });
    expect(api.get).not.toHaveBeenCalled();
    expect(carregando).toEqual([false]);
    expect(backlog.state.isLoading).toBe(false);
    expect(useAlert).not.toHaveBeenCalled();
  });

  it('o cartao arrastado passa a carregar o Sprint novo', async () => {
    const backlog = await montar();
    api.update.mockResolvedValue({});
    // O vuedraggable ja moveu o cartao de um balde para o outro.
    backlog.state.ticketsBySprint = {
      1: [...backlog.state.backlogTickets],
      2: [],
    };
    backlog.state.backlogTickets = [];

    await backlog.moveTicketToSprint(9, 1);

    expect(backlog.state.ticketsBySprint[1][0].sprint_id).toBe(1);
  });

  it('se o servidor recusar, avisa e desfaz recarregando, ainda sem o carregando', async () => {
    const backlog = await montar();
    api.update.mockRejectedValue(new Error('403'));
    const carregando = [];
    api.get.mockImplementation(() => {
      carregando.push(backlog.state.isLoading);
      return Promise.resolve({ data: { payload: [] } });
    });

    await backlog.moveTicketToSprint(9, 1);

    expect(useAlert).toHaveBeenCalledWith('TICKET.API.ERROR_MESSAGE');
    expect(api.get).toHaveBeenCalled();
    expect(carregando.every(valor => valor === false)).toBe(true);
    expect(backlog.state.isLoading).toBe(false);
  });
});
