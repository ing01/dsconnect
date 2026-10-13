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

  // Pedido: a Mesa do ticket vinculado precisa ser aparente - e e' informacao
  // do TICKET, nao de quem atende, entao nao pode depender de `showAssignee`
  // estar ligado (a aba "Minhas conversas" o deixa desligado de proposito,
  // por ser obvio quem atende) nem de haver responsavel.
  describe('the linked ticket Mesa', () => {
    it('shows it even when the assignee name is hidden (ex.: aba "Minhas conversas")', () => {
      const wrapper = mountComponent({ ticket_team_name: 'Suporte N2' });

      expect(
        wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
      ).toBe(true);
    });

    it('shows it alongside the assignee name when that is also visible', () => {
      const wrapper = shallowMount(ConversationCard, {
        props: {
          chat: { ...defaultChat, ticket_team_name: 'Suporte N2' },
          currentContact: { name: 'Jane Doe' },
          assignee: { name: 'Maria Suporte' },
          showAssignee: true,
          inbox: { id: 1 },
        },
        global: { stubs: { 'fluent-icon': true } },
      });

      expect(
        wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
      ).toBe(true);
    });

    // Sem Mesa, sem responsavel visivel, sem prioridade e sem "devolvida" -
    // a faixa inteira fica de fora (nao uma faixa vazia ocupando espaco).
    it('reserves no row at all when there is nothing to show in it', () => {
      const wrapper = mountComponent({ ticket_team_name: null });

      expect(
        wrapper.findComponent({ name: 'TicketMesaCardLabel' }).exists()
      ).toBe(false);
    });
  });
});
