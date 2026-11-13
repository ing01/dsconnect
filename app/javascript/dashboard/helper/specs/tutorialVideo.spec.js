import { resolveTutorialVideo, tutorialVideo } from '../tutorialVideo';

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
    expect(resolveTutorialVideo('https://x.com/a.mp4')).toEqual({
      type: 'video',
      src: 'https://x.com/a.mp4',
    });
  });
});

describe('tutorialVideo', () => {
  it('prefers the uploaded file over the link', () => {
    expect(
      tutorialVideo({
        video_file_url: '/f.mp4',
        video_url: 'https://youtu.be/dQw4w9WgXcQ',
      })
    ).toEqual({ type: 'video', src: '/f.mp4' });
  });

  it('is null for a tutorial without video', () => {
    expect(tutorialVideo({ video_file_url: null, video_url: null })).toBeNull();
  });
});
