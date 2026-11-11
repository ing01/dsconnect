import { actions, getters, mutations } from '../../ticketTimeEntries';
import TicketTimeEntriesAPI from 'dashboard/api/ticketTimeEntries';

// Cronometro de apontamento: o store guarda o do proprio agente por ticket e, ao
// finalizar, troca o cronometro por um apontamento da lista.
vi.mock('dashboard/api/ticketTimeEntries', () => ({
  default: {
    getTimers: vi.fn(),
    startTimer: vi.fn(),
    pauseTimer: vi.fn(),
    resumeTimer: vi.fn(),
    finishTimer: vi.fn(),
    discardTimer: vi.fn(),
  },
}));

const timer = (extra = {}) => ({
  id: 1,
  ticket_id: 10,
  status: 'running',
  elapsed_seconds: 60,
  ...extra,
});

describe('ticketTimeEntries, cronometro', () => {
  afterEach(() => vi.restoreAllMocks());

  describe('mutations', () => {
    it('guarda o cronometro com o instante em que a tela o recebeu', () => {
      vi.spyOn(Date, 'now').mockReturnValue(5000);
      const state = { timers: {} };

      mutations.SET_TIMERS(state, { ticketId: 10, timers: [timer()] });

      expect(state.timers[10]).toEqual([{ ...timer(), receivedAt: 5000 }]);
    });

    it('um ticket sem cronometro fica com a lista vazia', () => {
      const state = { timers: { 10: [{ ...timer(), receivedAt: 1 }] } };

      mutations.SET_TIMERS(state, { ticketId: 10, timers: [] });

      expect(getters.getTimersByTicket(state)(10)).toEqual([]);
      expect(getters.getTimersByTicket(state)(99)).toEqual([]);
    });

    it('congela o que corria nos outros tickets, somando o tempo decorrido', () => {
      vi.spyOn(Date, 'now').mockReturnValue(11000);
      const state = {
        timers: {
          10: [{ ...timer({ id: 1 }), receivedAt: 1000 }], // 10s depois
          20: [{ ...timer({ id: 2, ticket_id: 20 }), receivedAt: 1000 }],
        },
      };

      mutations.PAUSE_OTHER_TIMERS(state, { exceptTicketId: 20 });

      expect(state.timers[10][0]).toMatchObject({
        status: 'paused',
        elapsed_seconds: 70,
      });
      expect(state.timers[20][0].status).toBe('running');
    });

    it('nao mexe em quem ja estava pausado', () => {
      const state = {
        timers: { 10: [{ ...timer({ status: 'paused' }), receivedAt: 1 }] },
      };

      mutations.PAUSE_OTHER_TIMERS(state, { exceptTicketId: 20 });

      expect(state.timers[10][0].elapsed_seconds).toBe(60);
    });
  });

  describe('actions', () => {
    it('iniciar guarda o cronometro e pausa os dos outros tickets', async () => {
      TicketTimeEntriesAPI.startTimer.mockResolvedValue({ data: timer() });
      const commit = vi.fn();

      await actions.startTimer(
        { commit },
        { ticketId: 10, category: 'desenvolvimento', note: 'tela' }
      );

      expect(TicketTimeEntriesAPI.startTimer).toHaveBeenCalledWith(10, {
        category: 'desenvolvimento',
        note: 'tela',
      });
      expect(commit).toHaveBeenCalledWith('PAUSE_OTHER_TIMERS', {
        exceptTicketId: 10,
      });
      expect(commit).toHaveBeenCalledWith('SET_TIMERS', {
        ticketId: 10,
        timers: [timer()],
      });
    });

    it('pausar guarda a resposta do servidor', async () => {
      const paused = timer({ status: 'paused' });
      TicketTimeEntriesAPI.pauseTimer.mockResolvedValue({ data: paused });
      const commit = vi.fn();

      await actions.pauseTimer({ commit }, { ticketId: 10, timerId: 1 });

      expect(TicketTimeEntriesAPI.pauseTimer).toHaveBeenCalledWith(10, 1);
      expect(commit).toHaveBeenCalledWith('SET_TIMERS', {
        ticketId: 10,
        timers: [paused],
      });
    });

    it('continuar pausa os dos outros tickets', async () => {
      TicketTimeEntriesAPI.resumeTimer.mockResolvedValue({ data: timer() });
      const commit = vi.fn();

      await actions.resumeTimer({ commit }, { ticketId: 10, timerId: 1 });

      expect(commit).toHaveBeenCalledWith('PAUSE_OTHER_TIMERS', {
        exceptTicketId: 10,
      });
    });

    it('finalizar troca o cronometro por um apontamento da lista', async () => {
      const entry = { id: 77, hours: '1.5' };
      TicketTimeEntriesAPI.finishTimer.mockResolvedValue({ data: entry });
      const commit = vi.fn();

      const result = await actions.finishTimer(
        { commit },
        { ticketId: 10, timerId: 1 }
      );

      expect(result).toEqual(entry);
      expect(commit).toHaveBeenCalledWith('SET_TIMERS', {
        ticketId: 10,
        timers: [],
      });
      expect(commit).toHaveBeenCalledWith('ADD_ENTRY', { ticketId: 10, entry });
    });

    it('descartar tira o cronometro sem lancar nada', async () => {
      TicketTimeEntriesAPI.discardTimer.mockResolvedValue({});
      const commit = vi.fn();

      await actions.discardTimer({ commit }, { ticketId: 10, timerId: 1 });

      expect(commit).toHaveBeenCalledWith('SET_TIMERS', {
        ticketId: 10,
        timers: [],
      });
      expect(commit).not.toHaveBeenCalledWith('ADD_ENTRY', expect.anything());
    });

    it('se o servidor recusa, nada muda no store', async () => {
      TicketTimeEntriesAPI.finishTimer.mockRejectedValue(new Error('falhou'));
      const commit = vi.fn();

      await expect(
        actions.finishTimer({ commit }, { ticketId: 10, timerId: 1 })
      ).rejects.toThrow('falhou');
      expect(commit).not.toHaveBeenCalled();
    });
  });
});
