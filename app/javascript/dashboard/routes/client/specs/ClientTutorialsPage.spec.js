import { flushPromises, mount } from '@vue/test-utils';
import ClientAreaAPI from 'dashboard/api/clientArea';
import ClientTutorialsPage from '../pages/ClientTutorialsPage.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/clientArea', () => ({
  default: { tutorials: vi.fn() },
}));

const montar = async data => {
  ClientAreaAPI.tutorials.mockResolvedValue({ data });
  const wrapper = mount(ClientTutorialsPage, {
    global: { stubs: { Icon: true, PageLoader: true } },
  });
  await flushPromises();
  return wrapper;
};

describe('ClientTutorialsPage', () => {
  it('shows the empty message when there are no tutorials', async () => {
    const wrapper = await montar([]);

    expect(wrapper.find('[data-testid="tutorials-empty"]').exists()).toBe(true);
  });

  it('renders each tutorial with its description and a player for the video', async () => {
    const wrapper = await montar([
      {
        id: 1,
        title: 'Notificações',
        description: 'Passo 1\nPasso 2',
        video_url: 'https://youtu.be/dQw4w9WgXcQ',
        video_file_url: null,
      },
      {
        id: 2,
        title: 'Arquivo',
        description: null,
        video_url: null,
        video_file_url: '/rails/blob/a.mp4',
      },
      {
        id: 3,
        title: 'Sem vídeo',
        description: null,
        video_url: null,
        video_file_url: null,
      },
    ]);

    expect(
      wrapper.find('[data-testid="tutorial-1"] iframe').attributes('src')
    ).toBe('https://www.youtube.com/embed/dQw4w9WgXcQ');
    expect(wrapper.find('[data-testid="tutorial-1"]').text()).toContain(
      'Passo 1'
    );
    expect(
      wrapper.find('[data-testid="tutorial-2"] video').attributes('src')
    ).toBe('/rails/blob/a.mp4');
    expect(
      wrapper
        .find('[data-testid="tutorial-3"] [data-testid="tutorial-video-soon"]')
        .exists()
    ).toBe(true);
  });

  it('shows an error when the tutorials cannot be loaded', async () => {
    ClientAreaAPI.tutorials.mockRejectedValue(new Error('500'));
    const wrapper = mount(ClientTutorialsPage, {
      global: { stubs: { Icon: true, PageLoader: true } },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('CLIENT_AREA.TUTORIALS.ERROR');
  });
});
