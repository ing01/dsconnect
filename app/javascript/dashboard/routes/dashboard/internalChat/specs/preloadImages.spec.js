import { preloadImages } from '../helpers/preloadImages';

// Controla o "download": cada Image guarda o src e o exemplo decide quando termina.
let images;
class FakeImage {
  constructor() {
    images.push(this);
  }

  set src(value) {
    this.url = value;
  }
}

describe('preloadImages', () => {
  beforeEach(() => {
    images = [];
    vi.stubGlobal('Image', FakeImage);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('resolves at once when there is nothing to load', async () => {
    await preloadImages([null, undefined, '']);

    expect(images).toHaveLength(0);
  });

  it('waits for every picture, loaded or broken, without repeating urls', async () => {
    let done = false;
    const pending = preloadImages(['/a.png', '/b.png', '/a.png']).then(() => {
      done = true;
    });

    expect(images.map(image => image.url)).toEqual(['/a.png', '/b.png']);

    images[0].onload();
    await Promise.resolve();
    expect(done).toBe(false);

    images[1].onerror(); // foto quebrada nao prende a tela
    await pending;
    expect(done).toBe(true);
  });

  it('gives up after the timeout so a slow picture cannot block the screen', async () => {
    vi.useFakeTimers();
    let done = false;
    const pending = preloadImages(['/lenta.png'], { timeout: 1000 }).then(
      () => {
        done = true;
      }
    );

    await vi.advanceTimersByTimeAsync(999);
    expect(done).toBe(false);

    await vi.advanceTimersByTimeAsync(2);
    await pending;
    expect(done).toBe(true);
  });
});
