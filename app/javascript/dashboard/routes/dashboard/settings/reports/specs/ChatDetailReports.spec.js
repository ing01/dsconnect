import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import ChatDetailReports from '../ChatDetailReports.vue';
import ChatDetailReportsAPI from 'dashboard/api/chatDetailReports';
import { downloadBlob } from 'dashboard/helper/downloadHelper';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => {
  holder.dispatch = vi.fn();
  const lists = {
    'agents/getAgents': ref([{ id: 7, name: 'João Lucas' }]),
    'teams/getTeams': ref([{ id: 3, name: 'Suporte' }]),
    'inboxes/getInboxes': ref([{ id: 5, name: 'WhatsApp' }]),
  };
  return {
    useStore: () => ({ dispatch: holder.dispatch }),
    useMapGetter: name => lists[name],
  };
});
vi.mock('dashboard/helper/downloadHelper', () => ({ downloadBlob: vi.fn() }));
vi.mock('dashboard/api/chatDetailReports', () => ({
  default: { fetch: vi.fn(), exportXlsx: vi.fn() },
}));

const REPORT = {
  payload: [
    { id: 17743154, client: null, contact: 'Tonny Milan', wait: '19:22:08' },
  ],
  columns: [
    { key: 'id', label: 'ID' },
    { key: 'client', label: 'Cliente' },
    { key: 'contact', label: 'Conversado com' },
    { key: 'wait', label: 'Tempo de espera' },
  ],
  summary_columns: [
    { key: 'attended', label: 'Chats atendidos' },
    { key: 'cancelled', label: 'Chats cancelados' },
  ],
  summary: { attended: 883, cancelled: 29 },
  meta: { count: 60, page: 1, per_page: 25 },
};

const ButtonStub = {
  props: ['label', 'disabled'],
  template: '<button :disabled="disabled" v-bind="$attrs">{{ label }}</button>',
};

const mountPage = async () => {
  ChatDetailReportsAPI.fetch.mockResolvedValue({ data: REPORT });
  const wrapper = mount(ChatDetailReports, {
    global: { stubs: { Spinner: true, Button: ButtonStub } },
  });
  await flushPromises();
  return wrapper;
};

describe('ChatDetailReports', () => {
  beforeEach(() => vi.clearAllMocks());

  it('opens on the current month and loads the first page', async () => {
    await mountPage();

    const call = ChatDetailReportsAPI.fetch.mock.calls[0][0];
    expect(call.page).toBe(1);
    expect(call.from).toMatch(/^\d{4}-\d{2}-01$/);
    expect(call.to).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('shows the eight indicators and the table with the columns of the server', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('[data-testid="chat-summary-attended"]').text()).toBe(
      '883'
    );
    expect(wrapper.find('[data-testid="chat-summary-cancelled"]').text()).toBe(
      '29'
    );
    const headers = wrapper.findAll('th').map(th => th.text());
    expect(headers).toEqual([
      'ID',
      'Cliente',
      'Conversado com',
      'Tempo de espera',
    ]);
    // O que nao esta preenchido aparece como traco.
    const cells = wrapper.findAll('tbody td').map(td => td.text());
    expect(cells).toEqual(['17743154', '—', 'Tonny Milan', '19:22:08']);
  });

  it('applies the chosen filters, only the filled ones', async () => {
    const wrapper = await mountPage();
    ChatDetailReportsAPI.fetch.mockClear();

    const selects = wrapper.findAll('select');
    await selects[0].setValue(7); // responsavel
    await wrapper.find('[data-testid="chat-apply"]').trigger('click');

    const call = ChatDetailReportsAPI.fetch.mock.calls[0][0];
    expect(call).toMatchObject({ assignee_id: 7, page: 1 });
    expect(call.team_id).toBeUndefined();
    expect(call.status).toBeUndefined();
  });

  it('pages through the chats', async () => {
    const wrapper = await mountPage();
    ChatDetailReportsAPI.fetch.mockClear();

    await wrapper.find('[data-testid="chat-next"]').trigger('click');

    expect(ChatDetailReportsAPI.fetch.mock.calls[0][0].page).toBe(2);
    expect(
      wrapper.find('[data-testid="chat-prev"]').attributes('disabled')
    ).toBeDefined();
  });

  it('exports the Excel with the same filters', async () => {
    ChatDetailReportsAPI.exportXlsx.mockResolvedValue({
      data: new Blob(['x']),
      headers: { 'content-disposition': 'attachment; filename="chat.xlsx"' },
    });
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="chat-export"]').trigger('click');
    await flushPromises();

    expect(ChatDetailReportsAPI.exportXlsx).toHaveBeenCalledTimes(1);
    expect(
      ChatDetailReportsAPI.exportXlsx.mock.calls[0][0].page
    ).toBeUndefined();
    expect(downloadBlob).toHaveBeenCalled();
  });

  it('says so when there are no chats', async () => {
    ChatDetailReportsAPI.fetch.mockResolvedValue({
      data: {
        ...REPORT,
        payload: [],
        meta: { count: 0, page: 1, per_page: 25 },
      },
    });
    const wrapper = mount(ChatDetailReports, {
      global: { stubs: { Spinner: true, Button: ButtonStub } },
    });
    await flushPromises();

    expect(wrapper.find('[data-testid="chat-empty"]').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="chat-export"]').attributes('disabled')
    ).toBeDefined();
  });
});
