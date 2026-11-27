import { flushPromises, mount } from '@vue/test-utils';
import CustomerBriefingSummary from '../CustomerBriefingSummary.vue';
import CustomerBriefingAPI from 'dashboard/api/customerBriefing';

vi.mock('dashboard/api/customerBriefing', () => ({
  default: { summarize: vi.fn() },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const data = {
  generated_at: 1795780000,
  summary: {
    overview: 'Cliente com erro de nota.',
    recent_topics: ['Rejeição na NFS-e'],
    pending_items: ['Retornar sobre o #38016'],
    attention_points: [],
  },
};

const montar = async () => {
  const wrapper = mount(CustomerBriefingSummary, {
    props: { conversationId: 7, companyId: 1 },
    global: { stubs: { Icon: true }, directives: { tooltip: {} } },
  });
  await flushPromises();
  return wrapper;
};
const find = (wrapper, id) => wrapper.find(`[data-testid="${id}"]`);

describe('Resumo do cliente - texto da IA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CustomerBriefingAPI.summarize.mockResolvedValue({ data });
  });

  it('avisa que a IA esta lendo', async () => {
    CustomerBriefingAPI.summarize.mockReturnValue(new Promise(() => {}));
    const wrapper = await montar();

    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.LOADING');
  });

  it('mostra o texto e esconde as listas vazias', async () => {
    const wrapper = await montar();

    expect(wrapper.text()).toContain('Cliente com erro de nota.');
    expect(wrapper.text()).toContain('Rejeição na NFS-e');
    expect(wrapper.text()).toContain('Retornar sobre o #38016');
    expect(wrapper.text()).not.toContain('CUSTOMER_BRIEFING.AI.ATTENTION');
    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.DISCLAIMER');
  });

  it('nao interpreta HTML vindo da IA', async () => {
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { ...data, summary: { overview: '<img src=x onerror=alert(1)>' } },
    });
    const wrapper = await montar();

    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.text()).toContain('<img src=x');
  });

  it('atualizar pede um texto novo', async () => {
    const wrapper = await montar();

    await find(wrapper, 'briefing-refresh').trigger('click');
    await flushPromises();

    expect(CustomerBriefingAPI.summarize).toHaveBeenLastCalledWith(7, {
      companyId: 1,
      force: true,
    });
  });

  it('mantem o texto anterior quando atualizar falha', async () => {
    const wrapper = await montar();
    CustomerBriefingAPI.summarize.mockRejectedValue(new Error('x'));

    await find(wrapper, 'briefing-refresh').trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('Cliente com erro de nota.');
    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.ERROR');
  });

  it('mostra o motivo que o servidor mandou', async () => {
    CustomerBriefingAPI.summarize.mockRejectedValue({
      response: { data: { error: 'A chave de API não está configurada.' } },
    });
    const wrapper = await montar();

    expect(wrapper.text()).toContain('A chave de API não está configurada.');
    expect(find(wrapper, 'briefing-refresh').exists()).toBe(false);
  });

  it('tenta de novo depois de um erro', async () => {
    CustomerBriefingAPI.summarize.mockRejectedValueOnce(new Error('x'));
    const wrapper = await montar();

    await find(wrapper, 'briefing-summary-retry').trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('Cliente com erro de nota.');
    expect(wrapper.text()).not.toContain('CUSTOMER_BRIEFING.AI.ERROR');
  });

  it('avisa quando nao ha historico', async () => {
    CustomerBriefingAPI.summarize.mockResolvedValue({
      data: { summary: null, empty: true },
    });
    const wrapper = await montar();

    expect(wrapper.text()).toContain('CUSTOMER_BRIEFING.AI.EMPTY');
  });
});
