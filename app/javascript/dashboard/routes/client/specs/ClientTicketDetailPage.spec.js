import { mount, flushPromises } from '@vue/test-utils';
import ClientTicketDetailPage from '../pages/ClientTicketDetailPage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { ticketId: 12 } }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const ticket = {
  id: 12,
  display_id: 26,
  title: 'Erro na emissao da nota',
  status: 'open',
  priority: 'medium',
  ticket_column_name: 'A fazer',
  team_name: 'suporte',
  created_at: 1_790_000_000,
  // Uma descrição longa é o que espremia a barra de abas.
  description: 'linha\n'.repeat(200),
  communications: [{ id: 1, direction: 'outbound', body: 'Oi', subject: 'S' }],
  appointments: [],
  checklist_items: [],
};

vi.mock('dashboard/api/clientArea', () => ({
  default: {
    ticket: () => Promise.resolve({ data: ticket }),
    sendCommunication: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

const montar = async () => {
  const wrapper = mount(ClientTicketDetailPage, {
    global: {
      stubs: {
        Button: true,
        Spinner: true,
        Icon: true,
        Label: true,
        TextArea: true,
        TicketFileInput: true,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const abas = wrapper =>
  wrapper.findAll('button').filter(b => b.text().includes('CLIENT_AREA'));

describe('ClientTicketDetailPage', () => {
  it('shows the five tabs', async () => {
    const wrapper = await montar();

    expect(abas(wrapper).map(b => b.text())).toEqual([
      expect.stringContaining('TABS.OVERVIEW'),
      expect.stringContaining('TABS.COMMUNICATION'),
      expect.stringContaining('TABS.VALUATION'),
      expect.stringContaining('TABS.APPOINTMENTS'),
      expect.stringContaining('TABS.CHECKLIST'),
    ]);
  });

  // A regressão: num flex em coluna o encolhimento age na ALTURA, e uma
  // descrição longa espremia a faixa das abas até sobrar só a barra de
  // rolagem. `flex-shrink-0` é o que a mantém de pé.
  it('never lets the tab bar be squeezed by long content', async () => {
    const wrapper = await montar();
    const faixa = abas(wrapper)[0].element.parentElement;

    expect(faixa.className).toContain('flex-shrink-0');
  });

  // Cada aba rola por dentro; a página não cresce além da tela, senão o
  // cabeçalho e as abas saem de vista ao rolar.
  it('scrolls inside the tab content', async () => {
    const wrapper = await montar();
    const secao = wrapper.find('section');

    expect(secao.classes()).toContain('overflow-y-auto');
    expect(secao.classes()).toContain('min-h-0');
  });

  it('switches tabs on click', async () => {
    const wrapper = await montar();

    await abas(wrapper)[1].trigger('click');

    expect(wrapper.text()).toContain('CLIENT_AREA.DETAIL.COMMUNICATION');
  });
});
