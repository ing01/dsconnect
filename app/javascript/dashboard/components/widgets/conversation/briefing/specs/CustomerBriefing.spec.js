import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils';
import CustomerBriefingButton from '../CustomerBriefingButton.vue';
import CustomerBriefingAPI from 'dashboard/api/customerBriefing';

vi.mock('dashboard/api/customerBriefing', () => ({
  default: { getBriefing: vi.fn(), summarize: vi.fn() },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 1 }),
}));
const settings = { value: {} };
const updateUISettings = vi.fn(changes => {
  settings.value = { ...settings.value, ...changes };
});
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: settings, updateUISettings }),
}));

const open = vi.fn();
const close = vi.fn();
const DialogStub = {
  methods: { open, close },
  template: '<div><slot /></div>',
};

const briefing = {
  contact: {
    id: 5,
    name: 'Maria',
    previous_conversations_count: 1,
    notes: [],
  },
  companies: [
    { id: 1, name: 'Acme' },
    { id: 2, name: 'Beta' },
  ],
  company: {
    id: 1,
    name: 'Acme',
    status: 'active',
    blocked: false,
    system_modules: ['DS PDV'],
    tickets_count: 2,
    open_tickets_count: 1,
  },
  tickets: [{ id: 9, display_id: 38016, title: 'Erro NFSe', status: 'open' }],
  contact_conversations: [
    { display_id: 4, status: 'resolved', last_message: 'Erro na nota' },
  ],
  company_conversations: [],
};

const montar = (props = {}) =>
  mount(CustomerBriefingButton, {
    props: { conversationId: 7, ...props },
    global: {
      stubs: { Dialog: DialogStub, RouterLink: RouterLinkStub },
      directives: { tooltip: {} },
    },
  });

const abrir = async wrapper => {
  await wrapper.find('[data-testid="open-customer-briefing"]').trigger('click');
  await flushPromises();
};

describe('Resumo do cliente na conversa', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    settings.value = {};
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { summary: null, empty: true },
    });
    CustomerBriefingAPI.getBriefing.mockResolvedValue({ data: briefing });
  });

  it('so busca os dados quando o botao e clicado', async () => {
    const wrapper = montar();
    expect(CustomerBriefingAPI.getBriefing).not.toHaveBeenCalled();

    await abrir(wrapper);

    expect(open).toHaveBeenCalled();
    expect(CustomerBriefingAPI.getBriefing).toHaveBeenCalledWith(7, undefined);
    expect(wrapper.text()).toContain('#38016 — Erro NFSe');
    expect(wrapper.text()).toContain('Erro na nota');
  });

  it('leva ao ticket e a conversa, fechando o modal', async () => {
    const wrapper = montar();
    await abrir(wrapper);

    const [ticket, conversation] = wrapper.findAllComponents(RouterLinkStub);
    expect(ticket.props('to')).toBe('/app/accounts/1/tickets/9');
    expect(conversation.props('to')).toBe('/app/accounts/1/conversations/4');

    await ticket.trigger('click');
    expect(close).toHaveBeenCalled();
  });

  it('troca de empresa quando o contato tem mais de uma', async () => {
    const wrapper = montar();
    await abrir(wrapper);

    await wrapper.find('[data-testid="briefing-company"]').setValue('2');

    expect(CustomerBriefingAPI.getBriefing).toHaveBeenLastCalledWith(7, 2);
  });

  it('fecha pelo X e ao trocar de conversa', async () => {
    const wrapper = montar();
    await abrir(wrapper);

    await wrapper
      .find('[data-testid="close-customer-briefing"]')
      .trigger('click');
    await wrapper.setProps({ conversationId: 8 });

    expect(close).toHaveBeenCalledTimes(2);
  });

  it('mostra o erro e permite tentar de novo', async () => {
    CustomerBriefingAPI.getBriefing.mockRejectedValueOnce(new Error('x'));
    const wrapper = montar();
    await abrir(wrapper);

    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.ERROR');
  });
});

describe('Resumo do cliente - texto da IA no modal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    settings.value = {};
    CustomerBriefingAPI.getBriefing.mockResolvedValue({ data: briefing });
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { summary: null, empty: true },
    });
  });

  it('pede o texto da empresa mostrada, depois dos dados', async () => {
    const wrapper = montar();
    await abrir(wrapper);

    expect(CustomerBriefingAPI.summarize).toHaveBeenCalledWith(7, {
      companyId: 1,
      force: false,
    });
  });

  it('pede um novo texto ao trocar de empresa', async () => {
    const wrapper = montar();
    await abrir(wrapper);
    CustomerBriefingAPI.getBriefing.mockResolvedValue({
      data: { ...briefing, company: { ...briefing.company, id: 2 } },
    });

    await wrapper.find('[data-testid="briefing-company"]').setValue('2');
    await flushPromises();

    expect(CustomerBriefingAPI.summarize).toHaveBeenLastCalledWith(7, {
      companyId: 2,
      force: false,
    });
  });

  it('mantem os dados na tela quando a IA falha', async () => {
    CustomerBriefingAPI.summarize.mockRejectedValue(new Error('x'));
    const wrapper = montar();
    await abrir(wrapper);

    expect(wrapper.text()).toContain('#38016 — Erro NFSe');
    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.ERROR');
  });

  it('guarda a escolha de nao abrir sozinho', async () => {
    const wrapper = montar();
    await abrir(wrapper);
    const checkbox = wrapper.find('[data-testid="briefing-auto-open"]');
    expect(checkbox.element.checked).toBe(true);

    await checkbox.setValue(false);

    expect(updateUISettings).toHaveBeenCalledWith({
      customer_briefing_auto_open: false,
    });
  });
});

describe('Resumo do cliente - abertura automatica', () => {
  // O getter simulado devolve 1 para o usuario e para a conta.
  const minha = { assigneeId: 1, status: 'open' };

  beforeEach(() => {
    vi.clearAllMocks();
    settings.value = {};
    CustomerBriefingAPI.getBriefing.mockResolvedValue({ data: briefing });
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { summary: null, empty: true },
    });
  });

  it('abre ao ver uma conversa minha e lembra que ja mostrou', async () => {
    montar(minha);
    await flushPromises();

    expect(open).toHaveBeenCalledTimes(1);
    expect(settings.value.customer_briefing_seen).toEqual(['1:7']);
  });

  it('abre quando eu assumo a conversa que estou vendo', async () => {
    const wrapper = montar({ status: 'open' });
    expect(open).not.toHaveBeenCalled();

    await wrapper.setProps({ assigneeId: 1 });

    expect(open).toHaveBeenCalledTimes(1);
  });

  it('nao reabre ao voltar para a conversa', async () => {
    settings.value = { customer_briefing_seen: ['1:7'] };
    const wrapper = montar(minha);
    await wrapper.setProps({ conversationId: 8, assigneeId: 99 });
    await wrapper.setProps({ conversationId: 7, assigneeId: 1 });

    expect(open).not.toHaveBeenCalled();
  });

  it('abre uma vez para cada conversa assumida', async () => {
    const wrapper = montar(minha);
    await wrapper.setProps({ conversationId: 8 });
    await wrapper.setProps({ conversationId: 7 });

    expect(open).toHaveBeenCalledTimes(2);
    expect(settings.value.customer_briefing_seen).toEqual(['1:7', '1:8']);
  });

  it('nao abre com a opcao desligada', async () => {
    settings.value = { customer_briefing_auto_open: false };
    montar(minha);
    await flushPromises();

    expect(open).not.toHaveBeenCalled();
    expect(CustomerBriefingAPI.summarize).not.toHaveBeenCalled();
  });

  it.each([
    ['de outra pessoa', { assigneeId: 2, status: 'open' }],
    ['sem responsavel', { assigneeId: null, status: 'open' }],
    ['ja resolvida', { assigneeId: 1, status: 'resolved' }],
  ])('nao abre em conversa %s', async (_, props) => {
    montar(props);
    await flushPromises();

    expect(open).not.toHaveBeenCalled();
  });

  it('nao deixa a lista de conversas mostradas crescer sem fim', async () => {
    settings.value = {
      customer_briefing_seen: Array.from({ length: 200 }, (_, i) => `1:x${i}`),
    };
    montar(minha);
    await flushPromises();

    expect(settings.value.customer_briefing_seen).toHaveLength(200);
    expect(settings.value.customer_briefing_seen.at(-1)).toBe('1:7');
  });
});
