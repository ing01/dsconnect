import { mount } from '@vue/test-utils';
import ChatMessageBubble from '../ChatMessageBubble.vue';
import { quotedMessage } from 'dashboard/helper/clientChatText';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/clientArea', () => ({ default: {} }));

const mountBubble = message =>
  mount(ChatMessageBubble, {
    props: { message },
    global: { stubs: { Icon: true, Button: true, TextArea: true } },
  });

describe('ChatMessageBubble - reply quote', () => {
  const reply = reply_to =>
    mountBubble({
      id: 5,
      from_you: false,
      content: 'Pode sim',
      attachments: [],
      created_at: 1,
      reply_to,
    }).find('[data-testid="bubble-reply-to"]');

  it('quotes the client message being answered', () => {
    const quote = reply({ id: 1, content: 'tudo na Emporio', from_you: true });

    expect(quote.text()).toContain('CLIENT_AREA.CHAT.YOU');
    expect(quote.text()).toContain('tudo na Emporio');
  });

  it('names the agent and labels a quoted attachment', () => {
    const quote = reply({
      id: 2,
      content: '',
      from_you: false,
      author_name: 'Ana',
    });

    expect(quote.text()).toContain('Ana');
    expect(quote.text()).toContain('CLIENT_AREA.CHAT.ATTACHMENT');
  });

  it('shows no quote on a message that answers nothing', () => {
    expect(reply(undefined).exists()).toBe(false);
  });
});

describe('quotedMessage', () => {
  const messages = [{ id: 1, content: 'oi', from_you: true }];

  it('builds the quote from the messages on screen', () => {
    expect(quotedMessage(1, messages)).toMatchObject({ id: 1, content: 'oi' });
  });

  it('is empty without an id or when the original is not there', () => {
    expect(quotedMessage(undefined, messages)).toBeNull();
    expect(quotedMessage(99, messages)).toBeNull();
  });
});

describe('ChatMessageBubble - sending state', () => {
  it('shows "sending audio" while an audio message is pending, with no timestamp', () => {
    const wrapper = mountBubble({
      id: 'pending-1',
      from_you: true,
      pending: true,
      pending_kind: 'audio',
      attachments: [],
      created_at: 1,
    });

    expect(wrapper.find('[data-testid="bubble-sending"]').text()).toContain(
      'CLIENT_AREA.CHAT.SENDING_AUDIO'
    );
    expect(wrapper.text()).not.toContain('/');
  });

  it('shows "sending file" for attachments', () => {
    const wrapper = mountBubble({
      id: 'pending-2',
      from_you: true,
      pending: true,
      pending_kind: 'file',
      attachments: [],
    });

    expect(wrapper.find('[data-testid="bubble-sending"]').text()).toContain(
      'CLIENT_AREA.CHAT.SENDING_FILES'
    );
  });

  it('shows nothing extra for a plain pending text, nor once it was sent', () => {
    const text = mountBubble({
      id: 'pending-3',
      from_you: true,
      pending: true,
      pending_kind: null,
      content: 'oi',
      attachments: [],
    });
    const sent = mountBubble({
      id: 9,
      from_you: true,
      content: 'oi',
      attachments: [],
      created_at: 1,
    });

    expect(text.find('[data-testid="bubble-sending"]').exists()).toBe(false);
    expect(sent.find('[data-testid="bubble-sending"]').exists()).toBe(false);
  });
});
