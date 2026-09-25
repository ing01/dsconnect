import { flushPromises, mount } from '@vue/test-utils';
import { reactive, ref } from 'vue';
import TicketWorkspaceTabs from '../TicketWorkspaceTabs.vue';
import { workspaceTabsKey } from '../../../helpers/ticketWorkspaceTabs';

const push = vi.fn();
const route = reactive({ params: { accountId: '1', ticketId: undefined } });

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push }),
}));

const records = ref([]);
const currentUser = ref({ id: 7 });

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: getter => (getter === 'getCurrentUser' ? currentUser : records),
}));

const show = vi.fn();
vi.mock('dashboard/api/tickets', () => ({
  default: { show: (...args) => show(...args) },
}));

const ticket = (id, attributes = {}) => ({
  id,
  display_id: id,
  title: `Erro ${id}`,
  company_name: 'Eletrosul',
  requester_name: 'Joao Vitor',
  ...attributes,
});

// The composable keeps its state at module scope, so the bar survives leaving
// the module. Each test therefore takes its own user id, which is what makes
// the composable re-read storage instead of inheriting the previous tabs.
let userId = 100;
const mountBar = async ({ ticketId, stored } = {}) => {
  userId += 1;
  currentUser.value = { id: userId };
  route.params.ticketId = ticketId;
  if (stored) {
    window.localStorage.setItem(
      workspaceTabsKey('1', userId),
      JSON.stringify(stored)
    );
  }

  const wrapper = mount(TicketWorkspaceTabs, {
    global: { mocks: { $t: key => key } },
  });
  await flushPromises();
  return wrapper;
};

const tabs = wrapper => wrapper.findAll('[data-active-tab]');
const tabTexts = wrapper => tabs(wrapper).map(tab => tab.text());
const closeButton = (wrapper, index) =>
  tabs(wrapper)[index].findAll('button')[1];

// O jsdom nao faz layout: toda medida e zero, e sem forcar as dimensoes o
// transbordo nunca aconteceria no teste.
//
// Aqui a faixa tem 300px e cada aba 200px: cabe UMA (a segunda ja estouraria os
// 240px que sobram depois de reservar o botao "+"), e as outras duas vao para a
// lista.
const forcarTransbordo = async wrapper => {
  const faixa = tabs(wrapper)[0].element.parentElement;
  Object.defineProperty(faixa, 'clientWidth', {
    value: 300,
    configurable: true,
  });
  tabs(wrapper).forEach(tab => {
    Object.defineProperty(tab.element, 'offsetWidth', {
      value: 200,
      configurable: true,
    });
  });

  // A medicao roda quando as abas mudam e no redimensionamento - nao ha mais
  // rolagem para escutar.
  window.dispatchEvent(new Event('resize'));
  await flushPromises();
  await flushPromises();
};

const botaoTransbordo = wrapper =>
  wrapper.findAll('button').find(b => b.attributes('aria-expanded'));

describe('TicketWorkspaceTabs', () => {
  beforeEach(() => {
    push.mockClear();
    show.mockReset();
    show.mockImplementation(id =>
      Promise.resolve({ data: ticket(Number(id)) })
    );
    records.value = [];
    window.localStorage.clear();
  });

  it('stays out of the way until a Ticket is open', async () => {
    const wrapper = await mountBar();

    expect(wrapper.find('[data-active-tab]').exists()).toBe(false);
  });

  it('opens a tab for the Ticket in the route', async () => {
    records.value = [ticket(26)];
    const wrapper = await mountBar({ ticketId: '26' });

    expect(tabTexts(wrapper)).toHaveLength(1);
    expect(tabTexts(wrapper)[0]).toContain('#26');
    expect(tabTexts(wrapper)[0]).toContain('ELETROSUL');
  });

  // The rule this pins: the bar is keyed by Ticket, so coming back to one that
  // is already open must activate its tab rather than add a second.
  it('activates the existing tab instead of duplicating it', async () => {
    records.value = [ticket(26), ticket(27)];
    const wrapper = await mountBar({ ticketId: '26' });

    route.params.ticketId = '27';
    await flushPromises();
    route.params.ticketId = '26';
    await flushPromises();

    expect(tabTexts(wrapper)).toHaveLength(2);
  });

  it('marks only the Ticket in the route as active', async () => {
    records.value = [ticket(26), ticket(27)];
    const wrapper = await mountBar({ ticketId: '26' });
    route.params.ticketId = '27';
    await flushPromises();

    const active = wrapper.findAll('[data-active-tab="true"]');
    expect(active).toHaveLength(1);
    expect(active[0].text()).toContain('#27');
  });

  it('navigates to the Ticket of the tab that was clicked', async () => {
    records.value = [ticket(26), ticket(27)];
    const wrapper = await mountBar({ ticketId: '26' });
    route.params.ticketId = '27';
    await flushPromises();

    await tabs(wrapper)[0].find('button').trigger('click');

    expect(push).toHaveBeenCalledWith('/app/accounts/1/tickets/26');
  });

  // Closing a tab is a view action: it must not reach the server, because a
  // request from here would be a change to the Ticket itself.
  it('closes a tab without touching the Ticket', async () => {
    records.value = [ticket(26), ticket(27)];
    const wrapper = await mountBar({ ticketId: '26' });
    route.params.ticketId = '27';
    await flushPromises();
    show.mockClear();
    push.mockClear();

    await closeButton(wrapper, 0).trigger('click');

    expect(show).not.toHaveBeenCalled();
    expect(tabTexts(wrapper)).toHaveLength(1);
    // The closed tab was not the active one, so nothing navigates.
    expect(push).not.toHaveBeenCalled();
  });

  it('falls back to the tab on the left when the active one is closed', async () => {
    records.value = [ticket(26), ticket(27)];
    const wrapper = await mountBar({ ticketId: '26' });
    route.params.ticketId = '27';
    await flushPromises();

    await closeButton(wrapper, 1).trigger('click');

    expect(push).toHaveBeenCalledWith('/app/accounts/1/tickets/26');
  });

  it('returns to the Kanban when the last tab is closed', async () => {
    records.value = [ticket(26)];
    const wrapper = await mountBar({ ticketId: '26' });

    await closeButton(wrapper, 0).trigger('click');

    expect(push).toHaveBeenCalledWith('/app/accounts/1/tickets');
  });

  // Going back to the board is a route change like any other, and the tabs live
  // above the page, so none of them is lost.
  it('keeps the tabs open while the user is on the Kanban', async () => {
    records.value = [ticket(26)];
    const wrapper = await mountBar({ ticketId: '26' });

    route.params.ticketId = undefined;
    await flushPromises();

    expect(tabTexts(wrapper)).toHaveLength(1);
  });

  it('rewrites the label when the Ticket is renamed', async () => {
    records.value = [ticket(26)];
    const wrapper = await mountBar({ ticketId: '26' });

    records.value = [
      ticket(26, { title: 'Erro NF', company_name: 'Romafele' }),
    ];
    await flushPromises();

    expect(tabTexts(wrapper)[0]).toContain('ROMAFELE');
    expect(tabTexts(wrapper)[0]).toContain('Erro NF');
  });

  it('restores the tabs stored for this user', async () => {
    const wrapper = await mountBar({
      ticketId: '26',
      stored: { ticketIds: [26, 27], activeTicketId: 26 },
    });

    expect(tabTexts(wrapper)).toHaveLength(2);
  });

  // A stored id is not proof of access: the Ticket may have moved to a Mesa the
  // user is not on, so its tab is dropped rather than restored as a dead link.
  it('drops a restored tab the user can no longer open', async () => {
    show.mockImplementation(id =>
      Number(id) === 27
        ? Promise.reject(new Error('Forbidden'))
        : Promise.resolve({ data: ticket(Number(id)) })
    );

    const wrapper = await mountBar({
      ticketId: '26',
      stored: { ticketIds: [26, 27], activeTicketId: 26 },
    });

    expect(tabTexts(wrapper)).toHaveLength(1);
    expect(tabTexts(wrapper)[0]).toContain('#26');
  });

  // Rolar para procurar uma aba que nao se sabe onde esta e pior do que abrir
  // uma lista com todas.
  describe('transbordo', () => {
    // Tres abas: as do armazenamento mais a da rota.
    const abrirTres = async () => {
      records.value = [ticket(1), ticket(2), ticket(3)];
      const wrapper = await mountBar({
        ticketId: '1',
        stored: { ticketIds: [1, 2, 3], activeTicketId: 1 },
      });
      await forcarTransbordo(wrapper);
      return wrapper;
    };

    it('stays hidden while every tab fits', async () => {
      records.value = [ticket(1)];
      const wrapper = await mountBar({ ticketId: '1' });

      expect(botaoTransbordo(wrapper)).toBeUndefined();
    });

    it('counts the tabs that do not fit', async () => {
      const wrapper = await abrirTres();

      // A faixa cabe uma; duas ficam de fora.
      expect(botaoTransbordo(wrapper).text()).toContain('2');
    });

    // Sem rolagem: uma aba cortada pela metade nao se le, e procurar arrastando
    // e pior do que abrir a lista.
    it('never scrolls the strip', async () => {
      const wrapper = await abrirTres();
      const faixa = tabs(wrapper)[0].element.parentElement;

      expect(faixa.className).toContain('overflow-hidden');
      expect(faixa.className).not.toContain('overflow-x-auto');
    });

    it('draws only the tabs that fit', async () => {
      const wrapper = await abrirTres();

      const desenhadas = tabs(wrapper).filter(
        tab => tab.element.style.display !== 'none'
      );
      expect(desenhadas).toHaveLength(1);
    });

    it('lists every open tab, not only the hidden ones', async () => {
      const wrapper = await abrirTres();
      await botaoTransbordo(wrapper).trigger('click');

      const painel = wrapper.find('[aria-expanded="true"]').element
        .parentElement;
      expect(painel.textContent).toContain('#1');
    });

    it('closes a tab from the list', async () => {
      const wrapper = await abrirTres();
      await botaoTransbordo(wrapper).trigger('click');
      const antes = tabs(wrapper).length;

      const painel = wrapper.find('[aria-expanded="true"]').element
        .parentElement;
      const fechar = [...painel.querySelectorAll('button')].filter(b =>
        b.getAttribute('aria-label')
      );
      await fechar[fechar.length - 1].click();
      await flushPromises();

      expect(tabs(wrapper).length).toBeLessThan(antes);
    });
  });
});
