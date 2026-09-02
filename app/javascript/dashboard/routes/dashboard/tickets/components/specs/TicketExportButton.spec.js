import { mount, flushPromises } from '@vue/test-utils';
import TicketExportButton from '../TicketExportButton.vue';
import TicketsAPI from 'dashboard/api/tickets';
import { downloadBlob } from 'dashboard/helper/downloadHelper';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables', () => {
  holder.alert = vi.fn();
  return { useAlert: (...args) => holder.alert(...args) };
});

vi.mock('dashboard/api/tickets', () => ({
  default: { exportSearch: vi.fn() },
}));

vi.mock('dashboard/helper/downloadHelper', () => ({
  downloadBlob: vi.fn(),
}));

// Os mesmos filtros que a tela aplicou.
const FILTERS = {
  createdAfter: '2026-08-01',
  createdBefore: '2026-08-28',
  status: ['open', 'closed'],
  teamId: 1,
  ticketColumnIds: [11, 12],
  assigneeIds: [50, 51],
  companyIds: [7],
  contactIds: [],
  priority: [],
  categoryIds: [],
  displayId: '',
  title: '',
};

const mountButton = (props = {}) =>
  mount(TicketExportButton, {
    props: { filters: FILTERS, count: 12, ...props },
    global: {
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
        DropdownMenu: {
          props: { menuItems: { type: Array, default: () => [] } },
          template: `<ul data-menu>
            <li
              v-for="item in menuItems"
              :key="item.value"
              :data-value="item.value"
              @click="$emit('action', item)"
            >{{ item.label }}</li>
          </ul>`,
        },
      },
    },
  });

const trigger = wrapper => wrapper.find('button');
const menu = wrapper => wrapper.find('[data-menu]');
const open = async wrapper => {
  await trigger(wrapper).trigger('click');
  return wrapper;
};

describe('TicketExportButton', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    TicketsAPI.exportSearch.mockResolvedValue({
      data: new Blob(['x']),
      headers: {
        'content-disposition': 'attachment; filename="tickets-20260828.xlsx"',
      },
    });
  });

  it('offers exactly Excel and PDF', async () => {
    const wrapper = await open(mountButton());

    expect(
      menu(wrapper)
        .findAll('li')
        .map(item => item.attributes('data-value'))
    ).toEqual(['xlsx', 'pdf']);
  });

  // Exportar a página aberta não serviria: o arquivo tem de trazer a busca toda.
  it('sends the applied filters, without pagination', async () => {
    const wrapper = await open(mountButton());

    await wrapper.find('[data-value="xlsx"]').trigger('click');
    await flushPromises();

    const [params, format] = TicketsAPI.exportSearch.mock.calls[0];
    expect(format).toBe('xlsx');
    expect(params).toEqual({
      status: ['open', 'closed'],
      team_id: 1,
      ticket_column_id: [11, 12],
      assignee_id: [50, 51],
      company_id: [7],
      contact_id: undefined,
      priority: undefined,
      ticket_category_id: undefined,
      display_id: undefined,
      title: undefined,
      created_after: '2026-08-01',
      created_before: '2026-08-28',
    });
    expect(params.page).toBeUndefined();
    expect(params.per_page).toBeUndefined();
  });

  it('asks for the PDF when the PDF entry is chosen', async () => {
    const wrapper = await open(mountButton());

    await wrapper.find('[data-value="pdf"]').trigger('click');
    await flushPromises();

    expect(TicketsAPI.exportSearch.mock.calls[0][1]).toBe('pdf');
  });

  it('hands the file to the browser with the name the server sent', async () => {
    const wrapper = await open(mountButton());

    await wrapper.find('[data-value="xlsx"]').trigger('click');
    await flushPromises();

    expect(downloadBlob).toHaveBeenCalledWith(
      expect.any(Blob),
      'tickets.xlsx',
      'attachment; filename="tickets-20260828.xlsx"'
    );
  });

  it('closes the menu and shows it is working', async () => {
    let resolve;
    TicketsAPI.exportSearch.mockReturnValue(
      new Promise(done => {
        resolve = done;
      })
    );

    const wrapper = await open(mountButton());
    await wrapper.find('[data-value="xlsx"]').trigger('click');

    expect(menu(wrapper).exists()).toBe(false);
    expect(trigger(wrapper).text()).toBe('TICKET.EXPORT.WORKING');
    expect(trigger(wrapper).attributes('disabled')).toBeDefined();

    resolve({ data: new Blob(['x']), headers: {} });
    await flushPromises();
    expect(trigger(wrapper).text()).toBe('TICKET.EXPORT.LABEL');
  });

  // Enquanto o arquivo é montado, um segundo clique não pode disparar outro.
  it('does not start a second export while one is running', async () => {
    TicketsAPI.exportSearch.mockReturnValue(new Promise(() => {}));

    const wrapper = await open(mountButton());
    await wrapper.find('[data-value="xlsx"]').trigger('click');
    await trigger(wrapper).trigger('click');

    expect(menu(wrapper).exists()).toBe(false);
    expect(TicketsAPI.exportSearch).toHaveBeenCalledTimes(1);
  });

  describe('with nothing to export', () => {
    it('stays disabled and never opens', async () => {
      const wrapper = await open(mountButton({ count: 0 }));

      expect(trigger(wrapper).attributes('disabled')).toBeDefined();
      expect(menu(wrapper).exists()).toBe(false);
    });

    it('says why it is disabled', () => {
      const wrapper = mountButton({ count: 0 });

      expect(trigger(wrapper).attributes('title')).toBe('TICKET.EXPORT.EMPTY');
    });
  });

  // O erro do servidor chega como blob, porque o pedido esperava um arquivo.
  it('reports the reason the server refused', async () => {
    TicketsAPI.exportSearch.mockRejectedValue({
      response: {
        data: new Blob([JSON.stringify({ error: 'Busca grande demais.' })]),
      },
    });

    const wrapper = await open(mountButton());
    await wrapper.find('[data-value="xlsx"]').trigger('click');
    // A leitura do blob passa pelo FileReader, que nao e microtarefa nem tem
    // prazo fixo: sob carga ela passa de um tick, entao aqui se espera pelo
    // resultado em vez de por um tempo arbitrario.
    await vi.waitFor(() =>
      expect(holder.alert).toHaveBeenCalledWith('Busca grande demais.')
    );
    await flushPromises();

    expect(trigger(wrapper).attributes('disabled')).toBeUndefined();
  });
});
