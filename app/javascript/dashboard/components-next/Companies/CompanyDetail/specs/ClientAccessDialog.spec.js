import { mount, flushPromises } from '@vue/test-utils';
import ClientAccessDialog from '../ClientAccessDialog.vue';
import ContactAPI from 'dashboard/api/contacts';

// O bug real que motiva este arquivo: um erro de autorizacao (agente comum
// tentando ligar o acesso, que e' decisao de administrador - ver
// `ContactPolicy#client_access?`) manda `{ error: ... }`, nao `{ message: ... }`
// - e o dialogo so lia `message`, caindo sempre no texto generico e escondendo
// o motivo real. Ver `spec/controllers/api/v1/accounts/contact_client_access_spec.rb`
// para o mesmo defeito do lado do servidor.
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
const useAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => useAlert(...args),
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { setClientAccess: vi.fn() },
}));

const CONTATO = { id: 1, name: 'Cliente', email: 'cliente@exemplo.com.br' };

const montar = (props = {}) =>
  mount(ClientAccessDialog, {
    props: { contact: CONTATO, ...props },
    global: { stubs: { 'woot-modal-header': true } },
  });

const ligarEClicarSalvar = async wrapper => {
  await wrapper.find('input[type="checkbox"]').setValue(true);
  await wrapper.find('input[type="password"]').setValue('SenhaDoCliente@01');
  const salvar = wrapper
    .findAll('button')
    .find(botao => botao.text().includes('CLIENT_ACCESS.CONFIRM'));
  await salvar.trigger('click');
  await flushPromises();
};

describe('ClientAccessDialog', () => {
  beforeEach(() => useAlert.mockClear());

  it('shows a specific message when a non-administrator is denied (401, sem `message`)', async () => {
    ContactAPI.setClientAccess.mockRejectedValue({
      response: {
        status: 401,
        data: { error: 'You are not authorized to do this action' },
      },
    });

    await ligarEClicarSalvar(montar());

    expect(useAlert).toHaveBeenCalledWith(
      'COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.FORBIDDEN'
    );
  });

  it('shows the backend validation message when it comes as `message`', async () => {
    ContactAPI.setClientAccess.mockRejectedValue({
      response: {
        status: 422,
        data: { message: 'Password precisa ser definida' },
      },
    });

    await ligarEClicarSalvar(montar());

    expect(useAlert).toHaveBeenCalledWith('Password precisa ser definida');
  });

  // A maioria dos outros erros da API (fora validacao) manda `error`, nao
  // `message` - o dialogo precisa ler os dois, senao este caso cai no
  // generico do mesmo jeito que o 401 caia antes do conserto.
  it('falls back to the `error` key when there is no `message`', async () => {
    ContactAPI.setClientAccess.mockRejectedValue({
      response: {
        status: 500,
        data: { error: 'Falha inesperada no servidor' },
      },
    });

    await ligarEClicarSalvar(montar());

    expect(useAlert).toHaveBeenCalledWith('Falha inesperada no servidor');
  });

  it('only falls back to the generic text when the response has neither key', async () => {
    ContactAPI.setClientAccess.mockRejectedValue({
      response: { status: 500, data: {} },
    });

    await ligarEClicarSalvar(montar());

    expect(useAlert).toHaveBeenCalledWith(
      'COMPANIES.DETAIL.CONTACTS.CLIENT_ACCESS.ERROR'
    );
  });
});
