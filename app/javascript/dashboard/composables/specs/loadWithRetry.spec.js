import { useLoadWithRetry } from '../loadWithRetry';

// `Image` carrega de verdade no navegador; aqui simulamos o `onload`/`onerror`
// manualmente, como a imagem real dispararia.
class FakeImage {
  set src(_value) {
    FakeImage.instances.push(this);
  }
}
FakeImage.instances = [];

describe('useLoadWithRetry', () => {
  beforeEach(() => {
    FakeImage.instances = [];
    vi.stubGlobal('Image', FakeImage);
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  // app/javascript/dashboard/components-next/message/chips/Image.vue usava so
  // um `@error` sem retry: uma falha passageira de rede travava "Falha no
  // carregamento" para sempre, mesmo a URL sendo valida. Este e o
  // comportamento que o bubbles/Image.vue ja tinha e o chip passou a usar.
  it('recovers from a transient failure instead of giving up on the first error', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry();

    const promise = loadWithRetry('https://example.com/foto.png');
    await Promise.resolve();

    // Primeira tentativa falha...
    FakeImage.instances[0].onerror();
    await vi.advanceTimersByTimeAsync(1000);

    // ...a segunda tem sucesso, sem esperar as 3 tentativas do maximo.
    expect(FakeImage.instances).toHaveLength(2);
    FakeImage.instances[1].onload();
    await promise;

    expect(isLoaded.value).toBe(true);
    expect(hasError.value).toBe(false);
  });

  it('gives up only after exhausting every retry', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
      max_retry: 2,
      backoff: 100,
    });

    const promise = loadWithRetry('https://example.com/quebrada.png');
    await Promise.resolve();

    FakeImage.instances[0].onerror();
    await vi.advanceTimersByTimeAsync(100);
    FakeImage.instances[1].onerror();
    await promise;

    expect(FakeImage.instances).toHaveLength(2);
    expect(hasError.value).toBe(true);
    expect(isLoaded.value).toBe(false);
  });
});
