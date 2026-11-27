import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils';
import CustomerBriefingButton from '../CustomerBriefingButton.vue';
import CustomerBriefingAPI from 'dashboard/api/customerBriefing';

// Aqui o modal e' o de verdade: garante que ele ja existe quando a abertura
// automatica acontece e que o conteudo some ao fechar.
vi.mock('dashboard/api/customerBriefing', () => ({
  default: { getBriefing: vi.fn(), summarize: vi.fn() },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 1 }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));

const briefing = {
  contact: {
    id: 5,
    name: 'Maria',
    previous_conversations_count: 0,
    notes: [],
  },
  companies: [],
  company: null,
  tickets: [],
  contact_conversations: [],
  company_conversations: [],
};

const showModal = vi.fn();
const closeModal = vi.fn();
let wrapper;

const montar = async props => {
  wrapper = mount(CustomerBriefingButton, {
    props: { conversationId: 7, ...props },
    attachTo: document.body,
    global: {
      stubs: { RouterLink: RouterLinkStub, teleport: true },
      directives: { tooltip: {} },
      mocks: { $t: key => key },
    },
  });
  await flushPromises();
  return wrapper;
};
const content = () => wrapper.find('[data-testid="close-customer-briefing"]');

describe('Resumo do cliente - modal de verdade', () => {
  beforeAll(() => {
    HTMLDialogElement.prototype.showModal = showModal;
    HTMLDialogElement.prototype.close = closeModal;
  });

  beforeEach(() => {
    vi.clearAllMocks();
    CustomerBriefingAPI.getBriefing.mockResolvedValue({ data: briefing });
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { summary: null, empty: true },
    });
  });

  afterEach(() => wrapper.unmount());

  it('fica fechado e vazio em conversa de outra pessoa', async () => {
    await montar({ assigneeId: 2, status: 'open' });

    expect(showModal).not.toHaveBeenCalled();
    expect(content().exists()).toBe(false);
  });

  it('abre sozinho ja na montagem, com os dados e o texto', async () => {
    await montar({ assigneeId: 1, status: 'open' });

    expect(showModal).toHaveBeenCalledTimes(1);
    expect(wrapper.text()).toContain('Maria');
    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.EMPTY');
  });

  it('o X fecha e retira o conteudo', async () => {
    await montar({ assigneeId: 1, status: 'open' });

    await content().trigger('click');

    expect(closeModal).toHaveBeenCalled();
    expect(content().exists()).toBe(false);
  });

  it('abrir de novo busca os dados atualizados', async () => {
    await montar({ assigneeId: 2, status: 'open' });
    const open = wrapper.find('[data-testid="open-customer-briefing"]');

    await open.trigger('click');
    await flushPromises();
    await content().trigger('click');
    await open.trigger('click');
    await flushPromises();

    expect(CustomerBriefingAPI.getBriefing).toHaveBeenCalledTimes(2);
    expect(CustomerBriefingAPI.summarize).toHaveBeenCalledTimes(2);
  });
});
