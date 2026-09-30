import { actions, getters, mutations } from '../../ticketComplexities';
import types from '../../../mutation-types';
import TicketComplexitiesAPI from 'dashboard/api/ticketComplexities';

// Os níveis de Complexidade. Lista da CONTA - o que varia por Mesa é quais ela
// oferece, e é isso que o getter recorta.
vi.mock('dashboard/api/ticketComplexities', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

const LISTA = [
  { id: 1, name: 'Baixo', active: true, team_ids: [7, 8] },
  { id: 2, name: 'Alto', active: true, team_ids: [7] },
  { id: 3, name: 'Legado', active: false, team_ids: [7, 8] },
];

const estado = () => ({ records: LISTA, uiFlags: {} });

describe('os níveis de Complexidade', () => {
  it('reads the list from the server', async () => {
    TicketComplexitiesAPI.get.mockResolvedValue({
      data: { payload: LISTA },
    });
    const commit = vi.fn();

    await actions.fetch({ commit });

    expect(commit).toHaveBeenCalledWith(types.SET_TICKET_COMPLEXITIES, LISTA);
  });

  it('survives a payload that comes back empty', () => {
    const chatState = { records: LISTA, uiFlags: {} };

    mutations[types.SET_TICKET_COMPLEXITIES](chatState, undefined);

    expect(chatState.records).toEqual([]);
  });

  describe('o recorte por Mesa', () => {
    // O pedido: cada Mesa oferece um subconjunto dos níveis.
    it('offers only what that Mesa has enabled', () => {
      const disponiveis = getters.getComplexitiesForTeam(estado())(7);

      expect(disponiveis.map(item => item.name)).toEqual(['Baixo', 'Alto']);
    });

    it('offers less to a Mesa with fewer levels', () => {
      const disponiveis = getters.getComplexitiesForTeam(estado())(8);

      expect(disponiveis.map(item => item.name)).toEqual(['Baixo']);
    });

    // Desativado não aparece em Mesa nenhuma: `active` vale SOBRE a matriz.
    it('never offers a deactivated level, even where the Mesa has it', () => {
      const disponiveis = getters.getComplexitiesForTeam(estado())(7);

      expect(disponiveis.map(item => item.name)).not.toContain('Legado');
    });

    // Sem Mesa escolhida não há o que oferecer - e o formulário mostra o campo
    // desabilitado em vez de uma lista que não vale para ninguém.
    it('offers nothing while no Mesa is chosen', () => {
      expect(getters.getComplexitiesForTeam(estado())(null)).toEqual([]);
    });

    // O id vem da URL como texto em algumas telas.
    it('does not care whether the Mesa id is a number or a string', () => {
      expect(getters.getComplexitiesForTeam(estado())('7').length).toBe(2);
    });
  });

  // A tela de CONFIGURAÇÃO lista tudo, inclusive desativado: ele segue nos
  // tickets que o usam, e esconder faria parecer que foi apagado.
  it('lists everything to the settings screen, deactivated included', () => {
    expect(getters.getComplexities(estado()).map(item => item.name)).toEqual([
      'Baixo',
      'Alto',
      'Legado',
    ]);
  });

  describe('as alterações', () => {
    beforeEach(() => {
      TicketComplexitiesAPI.get.mockResolvedValue({ data: { payload: [] } });
    });

    // Criar um nível novo é dado, não código.
    it('creates a level', async () => {
      const dispatch = vi.fn();

      await actions.create({ dispatch, commit: vi.fn() }, { name: 'Crítico' });

      expect(TicketComplexitiesAPI.create).toHaveBeenCalledWith({
        ticket_complexity: { name: 'Crítico' },
      });
      // Relê a lista em vez de remendá-la: a alternativa é uma segunda cópia da
      // matriz que pode divergir.
      expect(dispatch).toHaveBeenCalledWith('fetch');
    });

    it('deactivates without deleting', async () => {
      const dispatch = vi.fn();

      await actions.update(
        { dispatch, commit: vi.fn() },
        { id: 2, active: false }
      );

      expect(TicketComplexitiesAPI.update).toHaveBeenCalledWith(2, {
        ticket_complexity: { active: false },
      });
    });

    // A matriz: a tela manda o conjunto completo de Mesas daquele nível.
    it('replaces the Mesas of a level', async () => {
      const dispatch = vi.fn();

      await actions.update(
        { dispatch, commit: vi.fn() },
        { id: 2, team_ids: [8] }
      );

      expect(TicketComplexitiesAPI.update).toHaveBeenCalledWith(2, {
        ticket_complexity: { team_ids: [8] },
      });
    });

    it('deletes a level', async () => {
      const dispatch = vi.fn();

      await actions.delete({ dispatch, commit: vi.fn() }, 3);

      expect(TicketComplexitiesAPI.delete).toHaveBeenCalledWith(3);
      expect(dispatch).toHaveBeenCalledWith('fetch');
    });
  });
});
