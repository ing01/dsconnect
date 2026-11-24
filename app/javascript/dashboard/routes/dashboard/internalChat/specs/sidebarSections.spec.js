import { mount } from '@vue/test-utils';
import ChatSidebar from '../components/ChatSidebar.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const USERS = [{ id: 2, name: 'Carla Reis', status: 'online' }];
const DIRECT = { id: 5, kind: 'direct', userId: 2, messages: [], unread: 2 };
const CHANNELS = [
  { id: 7, kind: 'channel', name: 'suporte', messages: [], unread: 3 },
  { id: 8, kind: 'channel', name: 'geral', messages: [], unread: 0 },
];

const montar = () =>
  mount(ChatSidebar, {
    props: { users: USERS, directs: [DIRECT], channels: CHANNELS },
    global: {
      stubs: {
        Icon: true,
        Avatar: { props: ['name'], template: '<span>{{ name }}</span>' },
      },
    },
  });

const cabecalho = (wrapper, chave) =>
  wrapper
    .findAll('button[aria-expanded]')
    .find(botao => botao.text().includes(chave));

describe('ChatSidebar, secoes recolhiveis', () => {
  beforeEach(() => localStorage.clear());

  it('mostra os canais ANTES das conversas privadas', () => {
    const texto = montar().text();

    expect(texto.indexOf('INTERNAL_CHAT.SIDEBAR.CHANNELS')).toBeLessThan(
      texto.indexOf('INTERNAL_CHAT.SIDEBAR.DIRECTS')
    );
  });

  it('recolher os canais esconde a lista e avisa o total de nao lidas', async () => {
    const wrapper = montar();
    expect(wrapper.text()).toContain('suporte');

    await cabecalho(wrapper, 'CHANNELS').trigger('click');

    expect(wrapper.text()).not.toContain('suporte');
    expect(cabecalho(wrapper, 'CHANNELS').text()).toContain('3');
    // As conversas privadas seguem a vista.
    expect(wrapper.text()).toContain('Carla Reis');
  });

  it('lembra a escolha ao abrir de novo', async () => {
    const primeiro = montar();
    await cabecalho(primeiro, 'DIRECTS').trigger('click');
    primeiro.unmount();

    const segundo = montar();

    expect(segundo.text()).not.toContain('Carla Reis');
    expect(cabecalho(segundo, 'DIRECTS').text()).toContain('2');
  });

  it('buscando, a secao recolhida aparece para nao esconder o resultado', async () => {
    const wrapper = montar();
    await cabecalho(wrapper, 'CHANNELS').trigger('click');
    expect(wrapper.text()).not.toContain('suporte');

    await wrapper.find('input[type="search"]').setValue('sup');

    expect(wrapper.text()).toContain('suporte');
  });
});
