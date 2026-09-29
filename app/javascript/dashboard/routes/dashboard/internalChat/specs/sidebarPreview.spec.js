import { mount } from '@vue/test-utils';
import ChatSidebar from '../components/ChatSidebar.vue';

// O defeito relatado: "Sem mensagens ainda" numa sala que TEM mensagens.
//
// A previa era lida de `room.messages`, e `messages` so e carregado quando a
// sala e ABERTA - a lista comeca vazia. Toda sala ainda nao visitada, portanto,
// se anunciava como vazia. `room.lastMessage` vem do servidor junto da lista.
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const USERS = [
  { id: 1, name: 'Maria Silva', status: 'online' },
  { id: 2, name: 'Carla Reis', status: 'offline' },
];

const sala = (extra = {}) => ({
  id: 5,
  kind: 'direct',
  userId: 2,
  messages: [],
  unread: 0,
  ...extra,
});

const montar = (props = {}) =>
  mount(ChatSidebar, {
    props: { users: USERS, directs: [], channels: [], ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        Avatar: { props: ['name'], template: '<span>{{ name }}</span>' },
      },
    },
  });

describe('ChatSidebar, a previa de cada sala', () => {
  // O caso que motivou tudo: a sala tem mensagem, mas ninguem a abriu ainda.
  it('shows the preview that came with the list, without opening the room', () => {
    const wrapper = montar({
      directs: [
        sala({
          lastMessage: {
            id: 9,
            userId: 2,
            body: 'Segue o retorno',
            createdAt: 1,
          },
        }),
      ],
    });

    expect(wrapper.text()).toContain('Segue o retorno');
    expect(wrapper.text()).not.toContain('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES');
  });

  // O que ja esta carregado vence: inclui a mensagem que acabou de chegar pelo
  // tempo real, mais nova do que a previa que veio com a lista.
  it('prefers what is already loaded over the preview from the list', () => {
    const wrapper = montar({
      directs: [
        sala({
          messages: [
            { id: 10, userId: 2, body: 'acabou de chegar', createdAt: 2 },
          ],
          lastMessage: { id: 9, userId: 2, body: 'a antiga', createdAt: 1 },
        }),
      ],
    });

    expect(wrapper.text()).toContain('acabou de chegar');
    expect(wrapper.text()).not.toContain('a antiga');
  });

  // Sala de verdade vazia continua dizendo que esta vazia.
  it('still says so when the room really has nothing', () => {
    const wrapper = montar({ directs: [sala()] });

    expect(wrapper.text()).toContain('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES');
  });

  // Mensagem so com anexo nao tem texto, e uma linha em branco na lista nao diz
  // nada a quem esta procurando a conversa.
  it('describes an attachment-only message instead of showing nothing', () => {
    const wrapper = montar({
      directs: [
        sala({
          lastMessage: {
            id: 9,
            userId: 2,
            body: '',
            createdAt: 1,
            hasAttachments: true,
          },
        }),
      ],
    });

    expect(wrapper.text()).toContain(
      'INTERNAL_CHAT.SIDEBAR.ATTACHMENT_PREVIEW'
    );
  });

  it('does not mistake whitespace for a message', () => {
    const wrapper = montar({
      directs: [
        sala({ lastMessage: { id: 9, userId: 2, body: '   ', createdAt: 1 } }),
      ],
    });

    expect(wrapper.text()).toContain('INTERNAL_CHAT.SIDEBAR.NO_MESSAGES');
  });
});
