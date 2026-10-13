import { shallowMount } from '@vue/test-utils';
import ConversationCardExpanded from '../ConversationCardExpanded.vue';

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};

const mountComponent = chat =>
  shallowMount(ConversationCardExpanded, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: { name: 'Jane Doe' },
      inbox: { id: 1 },
    },
    global: { stubs: { 'fluent-icon': true } },
  });

// O card expandido (`conversation_display_type` = "Expanded") nao tinha o
// rotulo de Mesa nenhum - o card condensado (ConversationCard.vue) ja tinha,
// mas quem usa o layout expandido nunca via a Mesa do ticket vinculado.
describe('ConversationCardExpanded', () => {
  it('shows the linked ticket Mesa', () => {
    const wrapper = mountComponent({ ticket_team_name: 'Suporte N2' });

    expect(
      wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
    ).toBe(true);
  });

  it('mounts fine without a linked ticket', () => {
    const wrapper = mountComponent({ ticket_team_name: null });

    expect(wrapper.exists()).toBe(true);
  });
});
