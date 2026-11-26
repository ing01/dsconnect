import { mount } from '@vue/test-utils';
import ChatMessage from '../components/ChatMessage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      [key.split('.').pop(), ...Object.values(params || {})].join('|'),
  }),
}));

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
