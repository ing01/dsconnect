import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import InternalChatPage from '../pages/InternalChatPage.vue';
import internalChat from 'dashboard/store/modules/internalChat';

const { holder } = vi.hoisted(() => ({ holder: { push: null } }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: holder.push }),
  useRoute: () => ({ params: { accountId: 1 }, query: {} }),
}));

// O store real do protótipo: ele não faz chamada nenhuma, então os testes
// exercitam exatamente o que a tela usa em produção.
const buildStore = () =>
  createStore({ modules: { internalChat: { ...internalChat } } });

const mountPage = async () => {
  holder.push = vi.fn();
  const store = buildStore();

  const wrapper = mount(InternalChatPage, {
    global: {
      plugins: [store],
      stubs: {
        Avatar: { props: ['name'], template: '<span>{{ name }}</span>' },
        Icon: true,
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open() {}, close() {} },
        },
        Button: { template: '<button />' },
        OnClickOutside: { template: '<div><slot /></div>' },
      },
    },
  });

  await flushPromises();
  return { wrapper, store };
};

const sidebarButtons = wrapper =>
  wrapper.findAll('aside button').map(button => button.text());

describe('InternalChatPage', () => {
  it('separates private conversations from channels', async () => {
    const { wrapper } = await mountPage();
    const labels = sidebarButtons(wrapper).join(' ');

    expect(labels).toContain('Maria Silva');
    expect(labels).toContain('suporte');
    // As duas listas têm cabeçalhos próprios, e não uma lista única.
    const headings = wrapper.findAll('aside h3').map(item => item.text());
    expect(headings).toEqual([
      'INTERNAL_CHAT.SIDEBAR.DIRECTS',
      'INTERNAL_CHAT.SIDEBAR.CHANNELS',
    ]);
  });

  it('opens the first conversation on arrival', async () => {
    const { wrapper } = await mountPage();

    expect(wrapper.text()).toContain('Conseguiu verificar?');
  });

  // Abrir a sala zera o não lido, e o badge do menu acompanha.
  it('clears the unread count of the room it opens', async () => {
    const { store } = await mountPage();

    expect(store.getters['internalChat/getRoomById']('d-maria').unread).toBe(0);
    expect(store.getters['internalChat/getUnreadCount']).toBe(7);
  });

  it('sends a message into the open room', async () => {
    const { wrapper, store } = await mountPage();

    await wrapper.find('textarea').setValue('Vou verificar agora.');
    await wrapper.find('textarea').trigger('keydown', { key: 'Enter' });

    const room = store.getters['internalChat/getRoomById']('d-maria');
    expect(room.messages.at(-1).body).toBe('Vou verificar agora.');
    expect(room.messages.at(-1).userId).toBe(1);
  });

  it('does not send on shift+enter, which is a line break', async () => {
    const { wrapper, store } = await mountPage();
    const before =
      store.getters['internalChat/getRoomById']('d-maria').messages.length;

    await wrapper.find('textarea').setValue('primeira linha');
    await wrapper.find('textarea').trigger('keydown', {
      key: 'Enter',
      shiftKey: true,
    });

    expect(
      store.getters['internalChat/getRoomById']('d-maria').messages
    ).toHaveLength(before);
  });

  // A referência a um Ticket é a integração que justifica o Chat morar dentro
  // da plataforma: ela leva ao Ticket de verdade.
  it('turns #32516 into a link to the ticket', async () => {
    const { wrapper } = await mountPage();

    const ticketButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('#32516'));

    expect(ticketButton).toBeTruthy();
    expect(ticketButton.text()).toContain('Erro na emissão da nota');

    await ticketButton.trigger('click');
    expect(holder.push).toHaveBeenCalledWith(
      expect.stringContaining('/tickets/32516')
    );
  });

  it('switches to a channel and shows its messages', async () => {
    const { wrapper } = await mountPage();

    const channelButton = wrapper
      .findAll('aside button')
      .find(button => button.text().includes('suporte'));
    await channelButton.trigger('click');

    expect(wrapper.text()).toContain('O cliente da ROMAFELE retornou?');
  });

  it('highlights a mention instead of leaving it as plain text', async () => {
    const { wrapper } = await mountPage();

    const channelButton = wrapper
      .findAll('aside button')
      .find(button => button.text().includes('suporte'));
    await channelButton.trigger('click');

    const mention = wrapper
      .findAll('span')
      .find(span => span.text() === '@Carla Reis');

    expect(mention).toBeTruthy();
    expect(mention.classes().join(' ')).toContain('bg-n-blue-3');
  });

  it('records a reaction on a message', async () => {
    const { wrapper, store } = await mountPage();

    const thumbsUp = wrapper
      .findAll('button')
      .find(button => button.text() === '👍');
    await thumbsUp.trigger('click');

    const room = store.getters['internalChat/getRoomById']('d-maria');
    const reacted = room.messages.some(message =>
      message.reactions.some(reaction => reaction.userIds.includes(1))
    );
    expect(reacted).toBe(true);
  });
});
