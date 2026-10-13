import { shallowMount } from '@vue/test-utils';
import ConversationCard from '../ConversationCard.vue';

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};

const mountComponent = (chat, currentContact = {}) =>
  shallowMount(ConversationCard, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: {
        name: 'Jane Doe',
        thumbnail: '',
        availability_status: 'offline',
        ...currentContact,
      },
      inbox: { id: 1 },
    },
    global: {
      stubs: {
        'fluent-icon': true,
      },
    },
  });

describe('ConversationCard', () => {
  it('does not reserve the labels row when only a persisted SLA policy id is present', () => {
    const wrapper = mountComponent({ sla_policy_id: 1, applied_sla: null });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the labels row when an active applied SLA is present', () => {
    const wrapper = mountComponent({
      sla_policy_id: 1,
      applied_sla: { id: 1 },
    });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
  });

  it('does not reserve the labels row when the contact is blocked', () => {
    const wrapper = mountComponent(
      {
        sla_policy_id: 1,
        applied_sla: { id: 1 },
      },
      { blocked: true }
    );

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  // Pedido: a Mesa do ticket vinculado ao lado de quem atende, pra dar pra
  // ver de cara se o assunto e' de uma Mesa ou de outra.
  describe('the linked ticket Mesa', () => {
    const mountWithAssignee = ticketTeamName =>
      shallowMount(ConversationCard, {
        props: {
          chat: { ...defaultChat, ticket_team_name: ticketTeamName },
          currentContact: { name: 'Jane Doe' },
          assignee: { name: 'Maria Suporte' },
          showAssignee: true,
          inbox: { id: 1 },
        },
        global: { stubs: { 'fluent-icon': true } },
      });

    it('shows it next to the assignee name when the ticket has a Mesa', () => {
      const wrapper = mountWithAssignee('Suporte N2');

      expect(
        wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
      ).toBe(true);
    });

    it('is not mounted when the assignee name is not shown', () => {
      // Mesmo gatilho que esconde o nome do agente (`showAssignee`/
      // `assignee.name`) - o rotulo de Mesa vive dentro do mesmo bloco, de
      // proposito: "ao lado do nome do agente" pressupoe que o nome apareca.
      const wrapper = mountComponent({ ticket_team_name: 'Suporte N2' });

      expect(
        wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
      ).toBe(false);
    });
  });
});
