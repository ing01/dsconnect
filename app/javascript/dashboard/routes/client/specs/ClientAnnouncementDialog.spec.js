import { flushPromises, mount } from '@vue/test-utils';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { clearSeenAnnouncements } from 'dashboard/helper/clientSession';
import { useClientAnnouncements } from 'dashboard/composables/useClientAnnouncements';
import ClientAnnouncementDialog from '../components/ClientAnnouncementDialog.vue';
import ClientAnnouncementBoard from '../components/ClientAnnouncementBoard.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/clientArea', () => ({
  default: { announcements: vi.fn() },
}));

const stubs = { Icon: true, Teleport: true };

const aviso = (id, extra = {}) => ({
  id,
  title: `Aviso ${id}`,
  body: 'Linha 1\nLinha 2',
  kind: 'info',
  link_url: null,
  link_label: null,
  ...extra,
});

const existe = (wrapper, testid) =>
  wrapper.find(`[data-testid="${testid}"]`).exists();

const montar = async (Component, announcements) => {
  // O composable guarda o estado no módulo: zera para cada montagem.
  const { announcements: lista, isLoaded } = useClientAnnouncements();
  lista.value = [];
  isLoaded.value = false;

  ClientAreaAPI.announcements.mockResolvedValue({ data: { announcements } });
  const wrapper = mount(Component, { global: { stubs } });
  await flushPromises();
  return wrapper;
};

describe('ClientAnnouncementDialog', () => {
  beforeEach(() => {
    window.sessionStorage.clear();
  });

  it('stays closed when there are no announcements', async () => {
    const wrapper = await montar(ClientAnnouncementDialog, []);

    expect(existe(wrapper, 'announcement-dialog')).toBe(false);
  });

  it('opens with the first announcement and shows the body as text', async () => {
    const wrapper = await montar(ClientAnnouncementDialog, [
      aviso(1, { body: '<b>x</b>' }),
    ]);

    expect(existe(wrapper, 'announcement-dialog')).toBe(true);
    expect(wrapper.find('[data-testid="announcement-title"]').text()).toBe(
      'Aviso 1'
    );
    // Texto puro: o HTML nunca vira marcação.
    expect(wrapper.find('b').exists()).toBe(false);
  });

  it('goes through the queue one announcement at a time', async () => {
    const wrapper = await montar(ClientAnnouncementDialog, [
      aviso(1),
      aviso(2),
    ]);

    await wrapper.find('[data-testid="announcement-dismiss"]').trigger('click');
    expect(wrapper.find('[data-testid="announcement-title"]').text()).toBe(
      'Aviso 2'
    );

    await wrapper.find('[data-testid="announcement-dismiss"]').trigger('click');
    expect(existe(wrapper, 'announcement-dialog')).toBe(false);
  });

  it('does not reopen an announcement already closed in this session', async () => {
    const first = await montar(ClientAnnouncementDialog, [aviso(1)]);
    await first.find('[data-testid="announcement-dismiss"]').trigger('click');

    const second = await montar(ClientAnnouncementDialog, [aviso(1)]);

    expect(existe(second, 'announcement-dialog')).toBe(false);
  });

  it('opens again after a new login clears the seen list', async () => {
    const first = await montar(ClientAnnouncementDialog, [aviso(1)]);
    await first.find('[data-testid="announcement-dismiss"]').trigger('click');
    clearSeenAnnouncements();

    const second = await montar(ClientAnnouncementDialog, [aviso(1)]);

    expect(existe(second, 'announcement-dialog')).toBe(true);
  });

  it('renders the link opening in a new tab without opener', async () => {
    const wrapper = await montar(ClientAnnouncementDialog, [
      aviso(1, { link_url: 'https://exemplo.com', link_label: 'Ver' }),
    ]);

    const link = wrapper.find('a');
    expect(link.attributes('href')).toBe('https://exemplo.com');
    expect(link.attributes('target')).toBe('_blank');
    expect(link.attributes('rel')).toContain('noopener');
  });
});

describe('ClientAnnouncementBoard', () => {
  it('renders nothing when there are no announcements', async () => {
    const wrapper = await montar(ClientAnnouncementBoard, []);

    expect(existe(wrapper, 'announcement-board')).toBe(false);
  });

  it('lists every announcement in effect', async () => {
    const wrapper = await montar(ClientAnnouncementBoard, [
      aviso(1),
      aviso(2, { kind: 'urgent' }),
    ]);

    expect(existe(wrapper, 'announcement-1')).toBe(true);
    expect(existe(wrapper, 'announcement-2')).toBe(true);
  });
});
