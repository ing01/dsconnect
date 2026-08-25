import { mount } from '@vue/test-utils';
import TicketConversationsDialog from '../TicketConversationsDialog.vue';

const push = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const conversation = (overrides = {}) => ({
  id: 14,
  display_id: 2,
  status: 'open',
  channel: 'Channel::Whatsapp',
  inbox_name: 'WhatsApp Suporte',
  contact_name: 'Renan',
  company_name: 'ELETROSUL',
  last_activity_at: 1_756_000_000,
  last_message: 'Segue a relacao de produtos',
  ...overrides,
});

const mountDialog = async (conversations = []) => {
  const wrapper = mount(TicketConversationsDialog, {
    props: { ticket: { id: 5, conversations } },
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open() {}, close() {} },
        },
        Icon: true,
        WootLabel: { props: ['label'], template: '<i>{{ label }}</i>' },
        // `emits` is what stops the double fire: without it Vue also passes the
        // parent's onClick through as a native attribute on the root button, so
        // one user click would reach the handler twice.
        Button: {
          props: ['label'],
          emits: ['click'],
          template: '<button @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });
  await wrapper.vm.open();
  return wrapper;
};

describe('TicketConversationsDialog', () => {
  beforeEach(() => push.mockClear());

  // A ticket opened straight from the Kanban has none; the dialog must still
  // render rather than showing an empty box.
  it('says so when nothing is linked', async () => {
    const wrapper = await mountDialog();

    expect(wrapper.text()).toContain('CONVERSATIONS_DIALOG.EMPTY');
    expect(wrapper.findAll('li')).toHaveLength(0);
  });

  // The action is never "abrir A conversa": a ticket can link any number.
  it('lists every linked conversation', async () => {
    const wrapper = await mountDialog([
      conversation(),
      conversation({ id: 15, display_id: 3 }),
      conversation({ id: 16, display_id: 4 }),
    ]);

    expect(wrapper.findAll('li')).toHaveLength(3);
  });

  it('uses the same list for a single conversation', async () => {
    const wrapper = await mountDialog([conversation()]);

    expect(wrapper.findAll('li')).toHaveLength(1);
  });

  it('shows channel, requester, company, inbox and the last message', async () => {
    const text = (await mountDialog([conversation()])).text();

    expect(text).toContain('WhatsApp');
    expect(text).toContain('Renan');
    expect(text).toContain('ELETROSUL');
    expect(text).toContain('WhatsApp Suporte');
    expect(text).toContain('Segue a relacao de produtos');
  });

  // "Channel::Whatsapp" is the class name, not something to show an agent.
  it('translates the raw channel class name', async () => {
    const text = (await mountDialog([conversation()])).text();

    expect(text).not.toContain('Channel::');
  });

  it('puts the most recently active conversation first', async () => {
    const wrapper = await mountDialog([
      conversation({ id: 14, display_id: 2, last_activity_at: 1 }),
      conversation({ id: 15, display_id: 3, last_activity_at: 999 }),
    ]);

    expect(wrapper.findAll('li')[0].text()).toContain('#3');
  });

  // The regression this pins: the dashboard route and the conversations API
  // both resolve on display_id, so navigating with the primary key opens
  // somebody else's conversation.
  it('navigates by display_id, not the internal id', async () => {
    const wrapper = await mountDialog([conversation()]);

    await wrapper.find('button').trigger('click');

    expect(push).toHaveBeenCalledTimes(1);
    const target = push.mock.calls[0][0];
    expect(target).toContain('/conversations/2');
    expect(target).not.toContain('/conversations/14');
  });

  it('opens the conversation that was clicked, not the first one', async () => {
    const wrapper = await mountDialog([
      conversation({ id: 14, display_id: 2, last_activity_at: 999 }),
      conversation({ id: 15, display_id: 7, last_activity_at: 1 }),
    ]);

    await wrapper.findAll('button')[1].trigger('click');

    expect(push.mock.calls[0][0]).toContain('/conversations/7');
  });
});
