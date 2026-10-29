import { mount } from '@vue/test-utils';
import ChatSidebar from '../components/ChatSidebar.vue';

// Botao direito na lista: conversa privada pode ser excluida por quem
// participa; canal so pelo administrador (que tambem edita).
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const USERS = [{ id: 2, name: 'Carla Reis', status: 'offline' }];
const DIRECT = { id: 5, kind: 'direct', userId: 2, messages: [], unread: 0 };
const CANAL = {
  id: 8,
  kind: 'channel',
  name: 'geral',
  messages: [],
  unread: 0,
};

const montar = (props = {}) =>
  mount(ChatSidebar, {
    props: { users: USERS, directs: [DIRECT], channels: [CANAL], ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        OnClickOutside: { template: '<div><slot /></div>' },
        Avatar: { props: ['name'], template: '<span>{{ name }}</span>' },
      },
    },
  });

const botoesDaLista = wrapper =>
  wrapper.findAll('section button[type="button"]').filter(b => b.text());

describe('ChatSidebar, excluir pelo botao direito', () => {
  it('oferece excluir numa conversa privada, sem editar, mesmo sem ser administrador', async () => {
    const wrapper = montar({ canEdit: false });
    const direct = botoesDaLista(wrapper).find(b => b.text().includes('Carla'));

    await direct.trigger('contextmenu');

    expect(wrapper.text()).toContain(
      'INTERNAL_CHAT.SIDEBAR.DELETE_CONVERSATION'
    );
    expect(wrapper.text()).not.toContain('INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL');
  });

  // O defeito: a conversa cujo par nao veio (userId nulo, avatar "?") era
  // tratada como canal e mostrava "Editar canal / Excluir canal".
  it('trata como conversa, e nunca como canal, a privada sem userId', async () => {
    const wrapper = montar({
      canEdit: true,
      directs: [{ ...DIRECT, id: 6, userId: null }],
    });
    await botoesDaLista(wrapper)[0].trigger('contextmenu');

    expect(wrapper.text()).toContain(
      'INTERNAL_CHAT.SIDEBAR.DELETE_CONVERSATION'
    );
    expect(wrapper.text()).not.toContain('INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL');
    expect(wrapper.text()).not.toContain('INTERNAL_CHAT.HEADER.DELETE_CHANNEL');
  });

  it('pede a exclusao da conversa ao clicar na opcao', async () => {
    const wrapper = montar({ canEdit: false });
    await botoesDaLista(wrapper)
      .find(b => b.text().includes('Carla'))
      .trigger('contextmenu');

    const excluir = wrapper
      .findAll('button')
      .find(b => b.text() === 'INTERNAL_CHAT.SIDEBAR.DELETE_CONVERSATION');
    await excluir.trigger('click');

    expect(wrapper.emitted('deleteRoom')[0][0].id).toBe(5);
  });

  it('nao abre o menu num canal para quem nao e administrador', async () => {
    const wrapper = montar({ canEdit: false });
    await botoesDaLista(wrapper)
      .find(b => b.text().includes('geral'))
      .trigger('contextmenu');

    expect(wrapper.text()).not.toContain('INTERNAL_CHAT.HEADER.DELETE_CHANNEL');
  });

  it('administrador pode editar e excluir o canal', async () => {
    const wrapper = montar({ canEdit: true });
    await botoesDaLista(wrapper)
      .find(b => b.text().includes('geral'))
      .trigger('contextmenu');

    expect(wrapper.text()).toContain('INTERNAL_CHAT.SIDEBAR.EDIT_CHANNEL');
    const excluir = wrapper
      .findAll('button')
      .find(b => b.text() === 'INTERNAL_CHAT.HEADER.DELETE_CHANNEL');
    await excluir.trigger('click');

    expect(wrapper.emitted('deleteRoom')[0][0].id).toBe(8);
  });
});
