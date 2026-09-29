import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import App from 'v3/App.vue';
import { LocalStorage } from 'shared/helpers/localStorage';

// A regressao que isto fixa: a tela de login olhava SO o sistema operacional e
// ignorava a escolha de quem usa. Quem tinha pedido escuro chegava ao login
// claro no celular, porque o aparelho estava no claro.
vi.mock('shared/helpers/localStorage');

const comSistemaEscuro = escuro => {
  const mql = { matches: escuro, onchange: null };
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => mql)
  );
  return mql;
};

const montar = async () => {
  const wrapper = mount(App, {
    global: {
      mocks: { $t: key => key },
      stubs: { 'router-view': true, SnackbarContainer: true },
    },
  });
  await nextTick();
  return wrapper;
};

beforeEach(() => {
  window.chatwootConfig = { selectedLocale: 'pt_BR' };
  document.body.classList.remove('dark');
  document.documentElement.classList.remove('dark');
});

afterEach(() => vi.unstubAllGlobals());

describe('v3 App (a casca do login)', () => {
  // O ponto central: a escolha gravada vence o aparelho.
  it('honours the saved choice over a light device', async () => {
    LocalStorage.get.mockReturnValue('dark');
    comSistemaEscuro(false);

    const wrapper = await montar();

    expect(wrapper.classes()).toContain('dark');
    expect(document.documentElement.classList.contains('dark')).toBe(true);
  });

  it('honours a light choice over a dark device', async () => {
    LocalStorage.get.mockReturnValue('light');
    comSistemaEscuro(true);

    const wrapper = await montar();

    expect(wrapper.classes()).toContain('light');
    expect(document.documentElement.classList.contains('dark')).toBe(false);
  });

  // Sem escolha nenhuma - primeiro acesso naquele aparelho - o sistema decide.
  it('follows the device when nothing was chosen', async () => {
    LocalStorage.get.mockReturnValue(undefined);
    comSistemaEscuro(true);

    const wrapper = await montar();

    expect(wrapper.classes()).toContain('dark');
  });

  // Quem pediu escuro nao quer que o amanhecer do celular acenda a tela.
  it('ignores the device changing when the choice is not auto', async () => {
    LocalStorage.get.mockReturnValue('dark');
    const mql = comSistemaEscuro(false);
    const wrapper = await montar();

    mql.onchange({ matches: false });
    await nextTick();

    expect(wrapper.vm.theme).toBe('dark');
    expect(document.documentElement.classList.contains('dark')).toBe(true);
  });

  it('follows the device changing while the choice is auto', async () => {
    LocalStorage.get.mockReturnValue('auto');
    const mql = comSistemaEscuro(false);
    const wrapper = await montar();
    expect(wrapper.vm.theme).toBe('light');

    mql.onchange({ matches: true });
    await nextTick();

    expect(wrapper.vm.theme).toBe('dark');
  });
});
