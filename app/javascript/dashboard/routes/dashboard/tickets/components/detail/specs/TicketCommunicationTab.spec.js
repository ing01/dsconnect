import { mount } from '@vue/test-utils';
import TicketCommunicationTab from '../TicketCommunicationTab.vue';

const push = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push }),
}));

const ticket = (conversations = []) => ({
  id: 5,
  conversations,
});

const mountTab = (conversations = []) =>
  mount(TicketCommunicationTab, {
    props: { ticket: ticket(conversations) },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        TicketComments: true,
        TicketCustomerCommunication: true,
      },
    },
  });

describe('TicketCommunicationTab', () => {
  beforeEach(() => push.mockClear());

  it('explains when nothing is linked', () => {
    expect(mountTab().text()).toContain('TICKET.DETAIL.NO_CONVERSATIONS');
  });

  it('lists the linked conversations with channel and requester', () => {
    const wrapper = mountTab([
      {
        id: 14,
        display_id: 2,
        status: 'open',
        channel: 'Channel::WebWidget',
        inbox_name: 'Suporte Web',
        contact_name: 'Renan',
      },
    ]);

    expect(wrapper.text()).toContain('#2');
    expect(wrapper.text()).toContain('Renan');
    expect(wrapper.text()).toContain('Suporte Web');
  });

  // The regression this pins: the dashboard route and the conversations API
  // both resolve on display_id, so navigating with the primary key opens
  // somebody else's conversation.
  it('navigates by display_id, not the internal id', async () => {
    const wrapper = mountTab([
      { id: 14, display_id: 2, status: 'open', inbox_name: 'Suporte Web' },
    ]);
    // The first buttons are the Interna/Cliente switch; the conversation link
    // is the one that is not a channel tab.
    const link = wrapper
      .findAll('button')
      .find(b => !b.attributes('data-channel'));
    await link.trigger('click');

    expect(push).toHaveBeenCalledTimes(1);
    const target = push.mock.calls[0][0];
    expect(target).toContain('/conversations/2');
    expect(target).not.toContain('/conversations/14');
  });

  // Internal notes never leave the account; customer messages are e-mails. The
  // two are never shown together.
  describe('the two audiences', () => {
    it('opens on the internal thread', () => {
      const wrapper = mountTab();

      expect(wrapper.findComponent({ name: 'TicketComments' }).exists()).toBe(
        true
      );
      expect(
        wrapper.findComponent({ name: 'TicketCustomerCommunication' }).exists()
      ).toBe(false);
    });

    it('swaps to the customer area, hiding the internal one', async () => {
      const wrapper = mountTab();

      await wrapper.find('[data-channel="customer"]').trigger('click');

      expect(
        wrapper.findComponent({ name: 'TicketCustomerCommunication' }).exists()
      ).toBe(true);
      expect(wrapper.findComponent({ name: 'TicketComments' }).exists()).toBe(
        false
      );
    });
  });

  it('keeps internal comments in their own section', () => {
    const wrapper = mountTab();

    expect(wrapper.findComponent({ name: 'TicketComments' }).exists()).toBe(
      true
    );
  });
});
