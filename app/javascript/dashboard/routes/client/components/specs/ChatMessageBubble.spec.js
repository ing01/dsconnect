import { mount } from '@vue/test-utils';
import ChatMessageBubble from '../ChatMessageBubble.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/clientArea', () => ({ default: {} }));

const mountBubble = message =>
  mount(ChatMessageBubble, {
    props: { message },
    global: { stubs: { Icon: true, Button: true, TextArea: true } },
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
