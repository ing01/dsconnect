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

describe('useBacklog > carregamento dos baldes', () => {
  const lote = (de, quantos) =>
    Array.from({ length: quantos }, (_, index) => ({ id: de + index }));
  const doBacklog = () =>
    api.get.mock.calls.map(([params]) => params).filter(p => p.without_sprint);
  const responder = paginas => {
    const total = new Set(paginas.flat().map(ticket => ticket.id)).size;
    api.get.mockImplementation(params =>
      Promise.resolve({
        data: {
          payload: params.without_sprint ? paginas[params.page - 1] || [] : [],
          meta: { count: params.without_sprint ? total : 0 },
        },
      })
    );
  };
  const carregar = async () => {
    api.get.mockClear();
    const backlog = useBacklog();
    backlog.selectTeam(5);
    await flushPromises();
    return backlog;
  };

  it('pede tambem os tickets sem pai', async () => {
    responder([[{ id: 1, parent_id: null }]]);

    const backlog = await carregar();

    expect(backlog.state.backlogTickets).toEqual([{ id: 1, parent_id: null }]);
    expect(api.get.mock.calls.every(([p]) => !('with_parent' in p))).toBe(true);
    expect(doBacklog()[0]).toMatchObject({
      team_id: 5,
      status: 'open',
      exclude_finalized_stage: true,
    });
  });

  it('busca todas as paginas, em ordem estavel', async () => {
    responder([lote(1, 100), lote(101, 100), lote(201, 30)]);

    const backlog = await carregar();

    expect(backlog.state.backlogTickets).toHaveLength(230);
    expect(doBacklog().map(p => p.page)).toEqual([1, 2, 3]);
    expect(doBacklog()[0]).toMatchObject({
      per_page: 100,
      sort_by: 'created_at',
      sort_order: 'desc',
    });
  });

  it('pagina cheia e sem resto nao pede outra', async () => {
    responder([lote(1, 100)]);

    await carregar();

    expect(doBacklog()).toHaveLength(1);
  });

  it('o ticket repetido na virada da pagina aparece uma vez', async () => {
    responder([lote(1, 100), lote(100, 3)]);

    const backlog = await carregar();

    expect(backlog.state.backlogTickets).toHaveLength(102);
  });

  it('resposta atrasada de outra Mesa nao troca a lista', async () => {
    let soltar;
    api.get.mockImplementation(params => {
      if (params.team_id === 5) {
        return new Promise(resolve => {
          soltar = () => resolve({ data: { payload: [{ id: 5 }] } });
        });
      }
      return Promise.resolve({
        data: { payload: params.team_id === 6 ? [{ id: 6 }] : [] },
      });
    });
    const backlog = await carregar();

    // O watch da troca de Mesa e' o proprio composable.
    backlog.selectTeam(6);
    await flushPromises();
    soltar();
    await flushPromises();

    expect(backlog.state.backlogTickets).toEqual([{ id: 6 }]);
  });
});

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
