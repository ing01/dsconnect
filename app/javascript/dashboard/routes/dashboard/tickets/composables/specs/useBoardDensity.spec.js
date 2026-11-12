const { size } = vi.hoisted(() => ({ size: { w: 1920, h: 1080 } }));
vi.mock('@vueuse/core', () => ({
  useWindowSize: () => ({
    width: {
      get value() {
        return size.w;
      },
    },
    height: {
      get value() {
        return size.h;
      },
    },
  }),
}));

// A escolha mora no modulo: cada teste carrega uma copia nova, como uma sessao nova.
const carregar = async () =>
  (await import('../useBoardDensity')).useBoardDensity;

describe('useBoardDensity', () => {
  beforeEach(() => {
    vi.resetModules();
    window.localStorage.clear();
    size.w = 1920;
    size.h = 1080;
  });

  it('segue o tamanho da janela enquanto a pessoa nao escolhe', async () => {
    const useBoardDensity = await carregar();

    expect(useBoardDensity().isCompact.value).toBe(false);
    size.w = 1280;
    size.h = 800;
    expect(useBoardDensity().isCompact.value).toBe(true);
  });

  it('o botao troca o tamanho e a escolha passa a valer em qualquer janela', async () => {
    const useBoardDensity = await carregar();
    const { isCompact, toggleDensity } = useBoardDensity();

    toggleDensity();
    expect(isCompact.value).toBe(true);

    toggleDensity();
    expect(isCompact.value).toBe(false);

    size.w = 1280;
    size.h = 800;
    // Escolheu "confortavel": vale mesmo na tela pequena.
    expect(useBoardDensity().isCompact.value).toBe(false);
  });

  it('duas telas (Kanban e Sprint) compartilham a mesma escolha', async () => {
    const useBoardDensity = await carregar();
    const kanban = useBoardDensity();
    const sprint = useBoardDensity();

    sprint.toggleDensity();

    expect(kanban.isCompact.value).toBe(true);
  });

  it('a escolha sobrevive a uma sessao nova (fica guardada no navegador)', async () => {
    const primeira = await carregar();
    primeira().toggleDensity();

    vi.resetModules();
    const segunda = await carregar();

    expect(segunda().isCompact.value).toBe(true);
  });
});
