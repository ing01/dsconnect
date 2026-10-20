import { actions, getters, mutations } from '../../manifestations';
import types from '../../../mutation-types';
import ManifestationsAPI from 'dashboard/api/manifestations';

vi.mock('dashboard/api/manifestations', () => ({
  default: {
    list: vi.fn(),
    show: vi.fn(),
    update: vi.fn(),
    create: vi.fn(),
    reply: vi.fn(),
    convert: vi.fn(),
    convertToSuggestion: vi.fn(),
  },
}));

const LISTA = [
  { id: 1, reference: 'SAC-1', status: 'received', title: 'Primeira' },
  { id: 2, reference: 'SAC-2', status: 'completed', title: 'Segunda' },
];

const estado = () => ({
  records: JSON.parse(JSON.stringify(LISTA)),
  detail: null,
  counts: { total: 2, pending: 1, untouched: 1 },
  uiFlags: {},
});

describe('o SAC no store', () => {
  describe('a listagem', () => {
    it('reads the list from the server', async () => {
      ManifestationsAPI.list.mockResolvedValue({
        data: { payload: LISTA, meta: { total: 2, pending: 1, untouched: 1 } },
      });
      const commit = vi.fn();

      await actions.fetch({ commit });

      expect(commit).toHaveBeenCalledWith(types.SET_MANIFESTATIONS, LISTA);
      expect(commit).toHaveBeenCalledWith(types.SET_MANIFESTATION_COUNTS, {
        total: 2,
        pending: 1,
        untouched: 1,
      });
    });

    // Os filtros vão para o SERVIDOR: filtrar no navegador obrigaria a baixar
    // o acervo inteiro para mostrar pouco.
    it('sends the filters to the server', async () => {
      ManifestationsAPI.list.mockResolvedValue({
        data: { payload: [], meta: {} },
      });

      await actions.fetch({ commit: vi.fn() }, { status: 'received', kind: 'complaint' });

      expect(ManifestationsAPI.list).toHaveBeenCalledWith({
        status: 'received',
        kind: 'complaint',
      });
    });

    it('survives a payload that comes back empty', () => {
      const chatState = estado();

      mutations[types.SET_MANIFESTATIONS](chatState, undefined);

      expect(chatState.records).toEqual([]);
    });

    // Os contadores vêm do servidor; sem eles a tela mostraria zero em vez de
    // quebrar.
    it('falls back to zeroes when the meta is missing', () => {
      const chatState = estado();

      mutations[types.SET_MANIFESTATION_COUNTS](chatState, undefined);

      expect(chatState.counts).toEqual({ total: 0, pending: 0, untouched: 0 });
    });
  });

  describe('o detalhe', () => {
    it('loads one manifestation with its messages', async () => {
      const detalhe = { id: 1, messages: [{ id: 9 }], activities: [] };
      ManifestationsAPI.show.mockResolvedValue({ data: detalhe });
      const commit = vi.fn();

      await actions.show({ commit }, 1);

      expect(commit).toHaveBeenCalledWith(
        types.SET_MANIFESTATION_DETAIL,
        detalhe
      );
    });

    it('changes the status through the server', async () => {
      ManifestationsAPI.update.mockResolvedValue({
        data: { id: 1, status: 'in_progress' },
      });

      await actions.update({ commit: vi.fn() }, { id: 1, status: 'in_progress' });

      expect(ManifestationsAPI.update).toHaveBeenCalledWith(1, {
        status: 'in_progress',
      });
    });

    // Responder relê o detalhe em vez de acrescentar a mensagem à mão: a
    // resposta pode ter mexido no status, e o histórico ganhou linhas que só o
    // servidor monta.
    it('re-reads the manifestation after replying', async () => {
      ManifestationsAPI.reply.mockResolvedValue({});
      const dispatch = vi.fn();

      await actions.reply(
        { commit: vi.fn(), dispatch },
        { id: 1, body: 'Oi', internal: false, awaitingCustomer: true }
      );

      expect(ManifestationsAPI.reply).toHaveBeenCalledWith(1, {
        body: 'Oi',
        internal: false,
        awaitingCustomer: true,
      });
      expect(dispatch).toHaveBeenCalledWith('show', 1);
    });

    it('passes the internal flag through when writing a note', async () => {
      ManifestationsAPI.reply.mockResolvedValue({});

      await actions.reply(
        { commit: vi.fn(), dispatch: vi.fn() },
        { id: 1, body: 'Nota', internal: true, awaitingCustomer: false }
      );

      expect(ManifestationsAPI.reply).toHaveBeenCalledWith(
        1,
        expect.objectContaining({ internal: true })
      );
    });
  });

  describe('a conversão em ticket', () => {
    it('converts through the server, with the chosen Mesa', async () => {
      ManifestationsAPI.convert.mockResolvedValue({
        data: { id: 1, converted: true, converted_ticket_display_id: 42 },
      });

      const dados = await actions.convert(
        { commit: vi.fn() },
        { id: 1, teamId: 7, ticketCategoryId: 3 }
      );

      expect(ManifestationsAPI.convert).toHaveBeenCalledWith(1, {
        teamId: 7,
        ticketCategoryId: 3,
      });
      expect(dados.converted).toBe(true);
    });
  });

  // Pedido: a outra saida, sem Mesa - so' a conta inteira tem UM quadro de
  // Sugestoes, entao nao ha o que escolher na chamada.
  describe('a conversão em sugestão', () => {
    it('converts through the server, without any team/category param', async () => {
      ManifestationsAPI.convertToSuggestion.mockResolvedValue({
        data: { id: 1, converted: true, converted_suggestion_id: 9 },
      });

      const dados = await actions.convertToSuggestion({ commit: vi.fn() }, 1);

      expect(ManifestationsAPI.convertToSuggestion).toHaveBeenCalledWith(1);
      expect(dados.converted_suggestion_id).toBe(9);
    });
  });

  describe('a linha da listagem depois de uma alteração', () => {
    // Mescla, não substitui: o corpo do detalhe traz campos que a linha da
    // lista não usa, e substituir apagaria o que a lista já tinha.
    it('merges the change into the row', () => {
      const chatState = estado();

      mutations[types.UPDATE_MANIFESTATION](chatState, {
        id: 1,
        status: 'in_progress',
      });

      expect(chatState.records[0]).toEqual({
        id: 1,
        reference: 'SAC-1',
        title: 'Primeira',
        status: 'in_progress',
      });
    });

    // Alterar algo que não está na lista carregada não pode inventar uma linha.
    it('ignores a manifestation that is not in the list', () => {
      const chatState = estado();

      mutations[types.UPDATE_MANIFESTATION](chatState, { id: 99, status: 'x' });

      expect(chatState.records).toHaveLength(2);
    });
  });

  it('exposes what the screens read', () => {
    const chatState = estado();

    expect(getters.getManifestations(chatState)).toHaveLength(2);
    expect(getters.getCounts(chatState).pending).toBe(1);
    expect(getters.getManifestation(chatState)).toBeNull();
  });
});
