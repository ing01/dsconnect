import { flushPromises, mount } from '@vue/test-utils';
import ClientAreaAPI from 'dashboard/api/clientArea';
import ClientTutorialsPage from '../pages/ClientTutorialsPage.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/clientArea', () => ({
  default: { tutorials: vi.fn() },
}));

const stubs = { Icon: true, PageLoader: true };

const montar = async (data = {}) => {
  ClientAreaAPI.tutorials.mockResolvedValue({
    data: { modules: [], tutorials: [], ...data },
  });
  const wrapper = mount(ClientTutorialsPage, { global: { stubs } });
  await flushPromises();
  return wrapper;
};

const tutorial = (id, extra = {}) => ({
  id,
  module_id: null,
  title: `Tutorial ${id}`,
  description: null,
  video_url: null,
  video_file_url: null,
  ...extra,
});

const existe = (wrapper, testid) =>
  wrapper.find(`[data-testid="${testid}"]`).exists();

describe('ClientTutorialsPage', () => {
  it('shows the empty message when there are no tutorials', async () => {
    const wrapper = await montar();

    expect(existe(wrapper, 'tutorials-empty')).toBe(true);
  });

  it('lists the videos directly when there are no modules', async () => {
    const wrapper = await montar({
      tutorials: [
        tutorial(1, {
          description: 'Passo 1\nPasso 2',
          video_url: 'https://youtu.be/dQw4w9WgXcQ',
        }),
        tutorial(2, { video_file_url: '/rails/blob/a.mp4' }),
        tutorial(3),
      ],
    });

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

  describe('with modules', () => {
    const dados = {
      modules: [
        { id: 10, name: 'DS Connect', description: 'Atendimento' },
        { id: 20, name: 'DS Comercial', description: null },
        { id: 30, name: 'Vazio', description: null },
      ],
      tutorials: [
        tutorial(1, { module_id: 10 }),
        tutorial(2, { module_id: 20 }),
        tutorial(3, { module_id: 20 }),
        tutorial(4),
      ],
    };

    it('shows one card per module with videos, plus "Geral" for loose ones', async () => {
      const wrapper = await montar(dados);

      expect(
        wrapper.find('[data-testid="tutorial-module-10"]').text()
      ).toContain('DS Connect');
      expect(existe(wrapper, 'tutorial-module-20')).toBe(true);
      expect(existe(wrapper, 'tutorial-module-30')).toBe(false);
      expect(existe(wrapper, 'tutorial-module-general')).toBe(true);
      // Os vídeos só aparecem depois de abrir o card.
      expect(existe(wrapper, 'tutorial-1')).toBe(false);
    });

    it('shows the logo on cards that have one and an icon on the others', async () => {
      const wrapper = await montar({
        ...dados,
        modules: [
          { ...dados.modules[0], logo_url: '/blob/logo.png' },
          dados.modules[1],
        ],
      });

      expect(
        wrapper.find('[data-testid="tutorial-module-10"] img').attributes('src')
      ).toBe('/blob/logo.png');
      expect(
        wrapper.find('[data-testid="tutorial-module-20"] img').exists()
      ).toBe(false);
    });

    it('opens a card to show only its videos and goes back', async () => {
      const wrapper = await montar(dados);

      await wrapper.find('[data-testid="tutorial-module-20"]').trigger('click');

      expect(existe(wrapper, 'tutorial-2')).toBe(true);
      expect(existe(wrapper, 'tutorial-3')).toBe(true);
      expect(existe(wrapper, 'tutorial-1')).toBe(false);
      expect(existe(wrapper, 'tutorial-4')).toBe(false);

      await wrapper.find('[data-testid="tutorials-back"]').trigger('click');

      expect(existe(wrapper, 'tutorial-module-20')).toBe(true);
      expect(existe(wrapper, 'tutorial-2')).toBe(false);
    });

    it('does not show the "Geral" card when every video has a module', async () => {
      const wrapper = await montar({
        ...dados,
        tutorials: dados.tutorials.filter(item => item.module_id),
      });

      expect(existe(wrapper, 'tutorial-module-general')).toBe(false);
    });
  });

  it('shows an error when the tutorials cannot be loaded', async () => {
    ClientAreaAPI.tutorials.mockRejectedValue(new Error('500'));
    const wrapper = mount(ClientTutorialsPage, { global: { stubs } });
    await flushPromises();

    expect(wrapper.text()).toContain('CLIENT_AREA.TUTORIALS.ERROR');
  });
});
