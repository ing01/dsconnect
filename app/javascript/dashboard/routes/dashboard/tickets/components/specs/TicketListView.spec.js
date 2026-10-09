import { mount } from '@vue/test-utils';
import TicketListView from '../TicketListView.vue';
import { collapsedColumnsKey } from '../../helpers/collapsedColumns';

// A lista tem DUAS origens: o store do painel e os grupos entregues por prop
// (o caminho da Área do Cliente). O que estes testes protegem é a separação -
// a origem entregue não pode disparar busca no store, e o painel não pode
// deixar de disparar.
const dispatch = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: (...args) => dispatch(...args),
    getters: {
      'tickets/getTicketsList': [],
      'tickets/getListMeta': { currentPage: 1, count: 0 },
      'tickets/getUIFlags': { isFetchingList: false },
    },
  }),
  useMapGetter: () => ({ value: 1 }),
}));

const ticket = (id, extra = {}) => ({
  id,
  display_id: id,
  title: `Chamado ${id}`,
  status: 'open',
  created_at: 1_790_000_000,
  company_name: 'ELETROSUL',
  requester_name: 'João Vitor',
  team_name: 'suporte',
  ticket_column_name: 'A fazer',
  assignee_name: 'Maria',
  ...extra,
});

// Na ordem da Mesa, que é o que a tela recebe - e não em ordem alfabética.
const GRUPOS = [
  { id: 10, name: 'Pendente', rows: [ticket(3), ticket(1)] },
  { id: 20, name: 'Aguardando o cliente', rows: [ticket(2)] },
];

const montar = (props = {}) =>
  mount(TicketListView, {
    props: { filters: {}, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: { Spinner: true, WootLabel: true, PaginationFooter: true },
    },
  });

const montarAgrupado = (props = {}) =>
  montar({ groups: GRUPOS, accountId: 1, teamId: 7, ...props });

// A faixa do Estágio é um botão; a linha do ticket, não.
const faixas = wrapper => wrapper.findAll('tbody button');
const linhasTicket = wrapper =>
  wrapper.findAll('tbody tr').filter(tr => !tr.find('button').exists());

beforeEach(() => {
  dispatch.mockClear();
  window.localStorage.clear();
});

describe('TicketListView', () => {
  // O painel continua como estava: sem `groups`, quem manda é o store.
  it('fetches from the store when no groups are handed in', () => {
    montar();

    expect(dispatch).toHaveBeenCalledWith(
      'tickets/fetchTickets',
      expect.objectContaining({ page: 1 })
    );
  });

  // A Área do Cliente já carregou os chamados para o Kanban. Buscar de novo
  // criaria uma segunda verdade - o mesmo botão alternando entre dois
  // conjuntos diferentes.
  it('never touches the store when groups are handed in', () => {
    montarAgrupado();

    expect(dispatch).not.toHaveBeenCalled();
  });

  it('draws one header per Estagio, in the order it was given', () => {
    const wrapper = montarAgrupado();

    expect(faixas(wrapper).map(f => f.text())).toEqual([
      expect.stringContaining('Pendente'),
      expect.stringContaining('Aguardando o cliente'),
    ]);
  });

  // A Área do Cliente, quando junta Mesas diferentes, entrega um grupo só e
  // sem nome - não há faixa de Estágio para desenhar, e as linhas aparecem
  // soltas (ver `ClientTicketsPage.vue`).
  it('draws no header for a nameless group, but keeps its rows', () => {
    const wrapper = montarAgrupado({
      groups: [{ id: 'all', name: '', rows: [ticket(1), ticket(2)] }],
    });

    expect(faixas(wrapper)).toHaveLength(0);
    expect(linhasTicket(wrapper)).toHaveLength(2);
  });

  // O número ao lado do nome é o que diz se vale a pena abrir o grupo.
  it('counts the tickets of each Estagio', () => {
    const wrapper = montarAgrupado();

    expect(faixas(wrapper)[0].text()).toContain('(2)');
    expect(faixas(wrapper)[1].text()).toContain('(1)');
  });

  it('shows every ticket while nothing is collapsed', () => {
    expect(linhasTicket(montarAgrupado())).toHaveLength(3);
  });

  // O pedido: esconder o Estágio que não interessa acompanhar.
  it('hides the tickets of a collapsed Estagio', async () => {
    const wrapper = montarAgrupado();

    await faixas(wrapper)[0].trigger('click');

    // Some só o grupo recolhido; a faixa dele continua, para poder reabrir.
    expect(linhasTicket(wrapper)).toHaveLength(1);
    expect(faixas(wrapper)).toHaveLength(2);
  });

  it('remembers what was collapsed', async () => {
    const wrapper = montarAgrupado();
    await faixas(wrapper)[0].trigger('click');

    expect(linhasTicket(montarAgrupado())).toHaveLength(1);
    expect(wrapper.exists()).toBe(true);
  });

  // Recolher na lista não pode recolher a coluna no Kanban: são duas formas de
  // ler o mesmo quadro.
  it('keeps its collapsed state apart from the Kanban one', async () => {
    const wrapper = montarAgrupado();

    await faixas(wrapper)[0].trigger('click');

    expect(window.localStorage.getItem(collapsedColumnsKey(1, 7))).toBeNull();
    expect(
      window.localStorage.getItem(collapsedColumnsKey(1, 7, 'list'))
    ).toContain('10');
  });

  // Quem entregou os dados é quem sabe para onde o clique leva: a rota interna
  // não serve para o cliente.
  it('hands the click back instead of routing', async () => {
    const wrapper = montarAgrupado({
      groups: [{ id: 10, name: 'Pendente', rows: [ticket(42)] }],
    });

    await linhasTicket(wrapper)[0].trigger('click');

    expect(wrapper.emitted('openTicket')[0]).toEqual([
      expect.objectContaining({ id: 42 }),
    ]);
  });

  // A ordenação vale DENTRO de cada Estágio: a separação é o que se pediu ver,
  // e ordenar por cima dela desmancharia os grupos.
  it('sorts inside each Estagio without a request', async () => {
    const wrapper = montarAgrupado();

    await wrapper.findAll('thead button')[0].trigger('click');

    expect(dispatch).not.toHaveBeenCalled();
    const numeros = linhasTicket(wrapper).map(l => l.findAll('td')[0].text());
    expect(numeros).toEqual(['#1', '#3', '#2']);
  });

  // Mesa, Estágio e Solicitante não estão em TICKET_SORT_FIELDS: com as linhas
  // em memória não há como ordená-los. O cabeçalho então não finge ser botão.
  it('does not offer a sort button it cannot honour', () => {
    const cabecalhos = montarAgrupado().findAll('thead th');

    // ID, Criado em, Título, Empresa, Solicitante, Status, Mesa, Estágio, Resp.
    expect(cabecalhos[4].find('button').exists()).toBe(false);
    expect(cabecalhos[6].find('button').exists()).toBe(false);
    expect(cabecalhos[0].find('button').exists()).toBe(true);
  });
});
