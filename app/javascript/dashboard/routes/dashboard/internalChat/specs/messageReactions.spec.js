import { flushPromises, mount } from '@vue/test-utils';
import ChatMessage from '../components/ChatMessage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      [key.split('.').pop(), ...Object.values(params || {})].join('|'),
  }),
}));

vi.mock(
  'dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue',
  () => ({
    __esModule: true,
    default: {
      name: 'EmojiPickerStub',
      emits: ['select'],
      template: '<div />',
    },
  })
);

const mountPicker = () =>
  mount(ChatMessage, {
    props: {
      message: { id: 1, userId: 2, body: '', createdAt: 0 },
      currentUserId: 1,
    },
    global: {
      stubs: {
        Avatar: true,
        Icon: true,
        MessageBody: true,
        Teleport: true,
      },
      directives: { tooltip: {} },
    },
  });
const picker = wrapper => wrapper.find('[data-testid="reaction-picker"]');
const openButton = wrapper =>
  wrapper.find('[data-testid="open-reaction-picker"]');

describe('ChatMessage - escolher outro emoji', () => {
  it('abre a lista completa, reage com o escolhido e fecha', async () => {
    const wrapper = mountPicker();
    expect(picker(wrapper).exists()).toBe(false);

    await openButton(wrapper).trigger('click');
    await vi.dynamicImportSettled();
    await flushPromises();
    wrapper
      .findComponent({ name: 'EmojiPickerStub' })
      .vm.$emit('select', { type: 'emoji', value: '🚀' });
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('react')).toEqual([[{ messageId: 1, emoji: '🚀' }]]);
    expect(picker(wrapper).exists()).toBe(false);
  });

  it('o mesmo botao fecha a lista', async () => {
    const wrapper = mountPicker();

    await openButton(wrapper).trigger('click');
    await openButton(wrapper).trigger('click');

    expect(picker(wrapper).exists()).toBe(false);
  });
});

const titleFor = userIds =>
  mount(ChatMessage, {
    props: {
      message: {
        id: 1,
        userId: 2,
        body: '',
        createdAt: 0,
        reactions: [{ emoji: '😂', userIds }],
      },
      users: [
        { id: 1, name: 'João' },
        { id: 2, name: 'Fernanda' },
        { id: 3, name: 'Diogo' },
      ],
      currentUserId: 1,
    },
    global: {
      stubs: { Avatar: true, Icon: true, MessageBody: true },
      directives: { tooltip: {} },
    },
  })
    .find('[data-testid="reaction"]')
    .attributes('aria-label');

describe('ChatMessage - quem reagiu', () => {
  it('mostra o nome de quem reagiu', () => {
    expect(titleFor([2])).toBe('REACTED_ONE|Fernanda|😂');
  });

  it('lista todo mundo, com a propria pessoa primeiro', () => {
    expect(titleFor([2, 3, 1])).toBe(
      'REACTED_MANY|NAMES_LIST|YOU, Fernanda|Diogo|😂'
    );
  });

  it('mantem quem ja nao esta na empresa', () => {
    expect(titleFor([99])).toBe('REACTED_ONE|UNKNOWN_USER|😂');
  });
});
