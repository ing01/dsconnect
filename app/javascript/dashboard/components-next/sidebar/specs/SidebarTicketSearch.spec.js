import { mount, flushPromises } from '@vue/test-utils';
import SidebarTicketSearch from '../SidebarTicketSearch.vue';

// O campo do menu lateral virou busca de CHAMADO, e só. O que estes testes
// protegem é a tradução: digita-se o NÚMERO (display_id), mas a rota do
// detalhe usa o id interno - abrir pelo número digitado levaria ao ticket
// errado.
const get = vi.fn();
const push = vi.fn();
const alerta = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));
vi.mock('dashboard/composables', () => ({ useAlert: (...a) => alerta(...a) }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 7 }),
}));
vi.mock('dashboard/api/tickets', () => ({
  default: { get: (...a) => get(...a) },
}));

const montar = (props = {}) =>
  mount(SidebarTicketSearch, {
    props,
    global: { stubs: { OnClickOutside: { template: '<div><slot /></div>' } } },
  });

const digitar = async (wrapper, texto) => {
  const campo = wrapper.find('input');
  await campo.setValue(texto);
  await campo.trigger('keyup.enter');
  await flushPromises();
};

beforeEach(() => {
  get.mockReset();
  push.mockReset();
  alerta.mockReset();
  get.mockResolvedValue({ data: { payload: [{ id: 901, display_id: 42 }] } });
});

describe('SidebarTicketSearch', () => {
  it('looks the ticket up by its number', async () => {
    await digitar(montar(), '42');

    expect(get).toHaveBeenCalledWith(
      expect.objectContaining({ display_id: '42' })
    );
  });

  // O ponto sensível: a rota recebe o id INTERNO (901), e não o número (42).
  it('opens the ticket by its internal id, not the number typed', async () => {
    await digitar(montar(), '42');

    expect(push).toHaveBeenCalledWith(expect.stringContaining('/tickets/901'));
    expect(push).not.toHaveBeenCalledWith(
      expect.stringContaining('/tickets/42')
    );
  });

  // O mesmo número é escrito de várias formas; todas querem dizer o mesmo.
  it('accepts the number however it is written', async () => {
    await digitar(montar(), '#42 ');

    expect(get).toHaveBeenCalledWith(
      expect.objectContaining({ display_id: '42' })
    );
  });

  it('does nothing without a number', async () => {
    await digitar(montar(), 'abc');

    expect(get).not.toHaveBeenCalled();
    expect(push).not.toHaveBeenCalled();
  });

  // Número que não existe precisa dizer isso - e não navegar para lugar nenhum.
  it('says so when no ticket carries that number', async () => {
    get.mockResolvedValue({ data: { payload: [] } });

    await digitar(montar(), '999');

    expect(push).not.toHaveBeenCalled();
    expect(alerta).toHaveBeenCalledWith('TICKET.SIDEBAR_SEARCH.NOT_FOUND');
  });

  it('survives a failing request', async () => {
    get.mockRejectedValue(new Error('rede'));

    await digitar(montar(), '42');

    expect(push).not.toHaveBeenCalled();
    expect(alerta).toHaveBeenCalledWith('TICKET.SIDEBAR_SEARCH.ERROR');
  });

  // Recolhido o trilho é estreito demais para um campo: o ícone abre um.
  it('hides the field behind the icon while the sidebar is collapsed', async () => {
    const wrapper = montar({ isCollapsed: true });
    expect(wrapper.find('input').exists()).toBe(false);

    await wrapper.find('button').trigger('click');

    expect(wrapper.find('input').exists()).toBe(true);
  });
});
