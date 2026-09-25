import { mount, flushPromises } from '@vue/test-utils';
import ClientLayout from '../ClientLayout.vue';

// O botão Sair. O defeito que estes testes fixam: havia um
// `router.replace({ name: 'client_login' })` antes do redirecionamento, e essa
// rota não existe - o Vue Router lança, a linha seguinte nunca rodava, e sair
// só surtia efeito depois de um F5.
const logout = vi.fn(() => Promise.resolve());
const clearClientSession = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/api/clientArea', () => ({
  default: { logout: (...args) => logout(...args) },
}));

vi.mock('dashboard/helper/clientSession', () => ({
  getClientSession: () => ({ contact: { name: 'João Vitor' } }),
  clearClientSession: (...args) => clearClientSession(...args),
  isSidebarCollapsed: () => false,
  setSidebarCollapsed: vi.fn(),
}));

const montar = () =>
  mount(ClientLayout, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        ClientSidebar: true,
        Icon: true,
        RouterView: true,
        // O Button de components-next repassa o clique; o stub reflete isso.
        Button: {
          props: { label: { type: String, default: '' } },
          template: '<button class="acao" @click="$emit(\'click\')" />',
        },
      },
    },
  });

const clicarSair = async wrapper => {
  await wrapper.findAll('button.acao').at(-1).trigger('click');
  await flushPromises();
};

let assign;

beforeEach(() => {
  logout.mockClear();
  clearClientSession.mockClear();
  assign = vi.fn();
  delete window.location;
  window.location = { assign, pathname: '/app/client/tickets' };
});

describe('ClientLayout', () => {
  it('leaves for the login screen on the click itself', async () => {
    await clicarSair(montar());

    expect(assign).toHaveBeenCalledWith('/app/login');
  });

  it('drops the session before leaving', async () => {
    await clicarSair(montar());

    expect(logout).toHaveBeenCalled();
    expect(clearClientSession).toHaveBeenCalled();
  });

  // Deixar o cookie para trás depois de clicar em sair é pior do que um token
  // órfão no servidor, que de todo modo não abre nada sem o acesso ligado.
  it('still leaves when the server call fails', async () => {
    logout.mockRejectedValueOnce(new Error('rede'));

    await clicarSair(montar());

    expect(clearClientSession).toHaveBeenCalled();
    expect(assign).toHaveBeenCalledWith('/app/login');
  });
});
