import { mount } from '@vue/test-utils';
import { resolveTutorialVideo, TUTORIALS } from '../tutorialsData';
import ClientTutorialsPage from '../pages/ClientTutorialsPage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('resolveTutorialVideo', () => {
  it('is null without an address', () => {
    expect(resolveTutorialVideo('')).toBeNull();
    expect(resolveTutorialVideo(undefined)).toBeNull();
  });

  it('turns YouTube links into the embedded player', () => {
    const embed = {
      type: 'iframe',
      src: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
    };

    expect(
      resolveTutorialVideo('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
    ).toEqual(embed);
    expect(resolveTutorialVideo('https://youtu.be/dQw4w9WgXcQ')).toEqual(embed);
    expect(
      resolveTutorialVideo('https://www.youtube.com/embed/dQw4w9WgXcQ')
    ).toEqual(embed);
  });

  it('turns Vimeo links into the embedded player', () => {
    expect(resolveTutorialVideo('https://vimeo.com/123456789')).toEqual({
      type: 'iframe',
      src: 'https://player.vimeo.com/video/123456789',
    });
  });

  it('plays any other address as a video file', () => {
    expect(resolveTutorialVideo('/tutoriais/ativar.mp4')).toEqual({
      type: 'video',
      src: '/tutoriais/ativar.mp4',
    });
  });
});

describe('ClientTutorialsPage', () => {
  it('lists the notifications tutorial, with "coming soon" while it has no video', () => {
    expect(TUTORIALS.map(t => t.id)).toContain('notifications');

    const wrapper = mount(ClientTutorialsPage, {
      global: { stubs: { Icon: true } },
    });

    expect(
      wrapper.find('[data-testid="tutorial-notifications"]').exists()
    ).toBe(true);
    expect(wrapper.find('[data-testid="tutorial-video-soon"]').exists()).toBe(
      TUTORIALS.find(t => t.id === 'notifications').videoUrl === ''
    );
  });
});
