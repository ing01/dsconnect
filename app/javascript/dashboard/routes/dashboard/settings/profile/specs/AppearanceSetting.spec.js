import { mount, flushPromises } from '@vue/test-utils';
import AppearanceSetting from '../AppearanceSetting.vue';

// O tema so podia ser escolhido pela barra de comandos (Ctrl+K), que num celular
// nao existe - e o celular era justamente onde o problema aparecia. A escolha
// tambem precisa VIAJAR: gravada so no `localStorage`, ela nao saia daquele
// navegador.
const updateUISettings = vi.fn(() => Promise.resolve());
const applyColorScheme = vi.fn();
const setUserColorScheme = vi.fn();
const storeColorScheme = vi.fn();
const alerta = vi.fn();
let uiSettings = {};

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: (...a) => alerta(...a) }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: uiSettings },
    updateUISettings: (...a) => updateUISettings(...a),
  }),
}));
vi.mock('dashboard/helper/themeHelper', () => ({
  applyColorScheme: (...a) => applyColorScheme(...a),
  setUserColorScheme: (...a) => setUserColorScheme(...a),
  storeColorScheme: (...a) => storeColorScheme(...a),
}));

const montar = () =>
  mount(AppearanceSetting, {
    global: { mocks: { $t: key => key }, stubs: { Icon: true } },
  });

const botoes = wrapper => wrapper.findAll('button');
const marcado = wrapper =>
  botoes(wrapper).findIndex(b => b.attributes('aria-pressed') === 'true');

beforeEach(() => {
  updateUISettings.mockClear();
  applyColorScheme.mockClear();
  setUserColorScheme.mockClear();
  storeColorScheme.mockClear();
  alerta.mockClear();
  uiSettings = {};
});

describe('AppearanceSetting', () => {
  it('offers the three choices', () => {
    expect(botoes(montar())).toHaveLength(3);
  });

  // Sem escolha gravada o sistema segue o aparelho, e a tela diz isso em vez de
  // mostrar "Claro" marcado por acaso.
  it('marks "follow the device" when nothing was chosen', () => {
    expect(marcado(montar())).toBe(2);
  });

  it('marks what the user chose before', () => {
    uiSettings = { color_scheme: 'dark' };

    expect(marcado(montar())).toBe(1);
  });

  // O ponto central: a escolha vai para o USUARIO, e e o que a faz valer no
  // celular.
  it('saves the choice on the user', async () => {
    const wrapper = montar();

    await botoes(wrapper)[1].trigger('click');
    await flushPromises();

    expect(updateUISettings).toHaveBeenCalledWith({ color_scheme: 'dark' });
  });

  // E tambem neste navegador, porque a tela de LOGIN nao tem usuario de quem
  // herdar preferencia.
  it('keeps it in this browser too, for the login screen', async () => {
    const wrapper = montar();

    await botoes(wrapper)[1].trigger('click');

    expect(storeColorScheme).toHaveBeenCalledWith('dark');
    expect(setUserColorScheme).toHaveBeenCalledWith('dark');
  });

  // Pintar antes de a rede responder: tema e resposta a um toque.
  it('paints the screen before the server answers', async () => {
    const wrapper = montar();

    await botoes(wrapper)[1].trigger('click');

    expect(applyColorScheme).toHaveBeenCalled();
  });

  it('does nothing when the choice is already the current one', async () => {
    uiSettings = { color_scheme: 'dark' };
    const wrapper = montar();

    await botoes(wrapper)[1].trigger('click');

    expect(updateUISettings).not.toHaveBeenCalled();
  });

  // Falha de rede nao pode passar em silencio: a tela ja mudou de cor, e sem
  // aviso a pessoa acreditaria que ficou gravado.
  it('says so when saving fails', async () => {
    updateUISettings.mockRejectedValueOnce(new Error('rede'));
    const wrapper = montar();

    await botoes(wrapper)[0].trigger('click');
    await flushPromises();

    expect(alerta).toHaveBeenCalledWith(
      'PROFILE_SETTINGS.FORM.API.UPDATE_ERROR'
    );
  });
});
