import { mount, flushPromises } from '@vue/test-utils';
import TicketCommunicationTab from '../TicketCommunicationTab.vue';

const push = vi.fn();
const dispatch = vi.fn();
const getAttendance = vi.fn();

// Com os parametros no texto: o aviso precisa nomear o agente e a conversa.
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

vi.mock('dashboard/api/contacts', () => ({
  default: { getAttendance: (...args) => getAttendance(...args) },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push }),
}));

// A aba carrega o solicitante na store de contatos: e' de la que o formulario de nova
// conversa le o contato e as caixas de entrada dele.
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

const ticket = (conversations = [], contact = { id: 77, name: 'Renan' }) => ({
  id: 5,
  conversations,
  contact,
});

// O formulario de nova conversa em si e' do ComposeConversation (e tem teste proprio):
// aqui interessa o que a aba lhe entrega e o que faz quando ele avisa que criou.
const ComposeStub = {
  props: ['contactId', 'ticketId'],
  emits: ['created'],
  template: `
    <div class="compose" :data-contact="contactId" :data-ticket="ticketId">
      <slot name="trigger" />
      <button class="criou" @click="$emit('created', { id: 9 })" />
    </div>`,
};

const mountTab = (conversations = [], contact) =>
  mount(TicketCommunicationTab, {
    props: { ticket: ticket(conversations, contact) },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        TicketComments: true,
        TicketCustomerCommunication: true,
        ComposeConversation: ComposeStub,
        Button: {
          props: ['label'],
          template: '<button>{{ label }}</button>',
        },
      },
    },
  });

describe('TicketCommunicationTab', () => {
  beforeEach(() => {
    push.mockClear();
    dispatch.mockClear();
    getAttendance.mockReset();
    getAttendance.mockResolvedValue({ data: { in_attendance: false } });
  });

  // O servidor ja recusa abrir outra conversa com um cliente que OUTRO agente atende; a tela
  // antecipa o motivo, assim que a aba abre, em vez de so' avisar depois do envio.
  describe('cliente ja em atendimento', () => {
    const emAtendimento = {
      in_attendance: true,
      assignee_name: 'Maria Atendente',
      conversation_id: 41,
      account_id: 1,
    };

    it('asks the server who is attending the requester', async () => {
      mountTab();
      await flushPromises();

      expect(getAttendance).toHaveBeenCalledWith(77);
    });

    it('warns with the name of the agent and the conversation, instead of the button', async () => {
      getAttendance.mockResolvedValue({ data: emAtendimento });
      const wrapper = mountTab();
      await flushPromises();

      const aviso = wrapper.find('[data-testid="in-attendance"]');
      expect(aviso.exists()).toBe(true);
      expect(aviso.text()).toContain('Maria Atendente');
      expect(aviso.text()).toContain('"id":41');
      expect(wrapper.find('.compose').exists()).toBe(false);
    });

    it('takes the person to that conversation by its display id', async () => {
      getAttendance.mockResolvedValue({ data: emAtendimento });
      const wrapper = mountTab();
      await flushPromises();

      await wrapper.find('[data-testid="open-attendance"]').trigger('click');

      expect(push.mock.calls[0][0]).toContain('/conversations/41');
    });

    it('does not warn, and keeps the button, when nobody is attending', async () => {
      const wrapper = mountTab();
      await flushPromises();

      expect(wrapper.find('[data-testid="in-attendance"]').exists()).toBe(false);
      expect(wrapper.find('.compose').exists()).toBe(true);
    });

    // O servidor continua barrando a abertura; sem o aviso a tela segue normal.
    it('keeps the button when the check fails', async () => {
      getAttendance.mockRejectedValue(new Error('rede'));
      const wrapper = mountTab();
      await flushPromises();

      expect(wrapper.find('[data-testid="in-attendance"]').exists()).toBe(false);
      expect(wrapper.find('.compose').exists()).toBe(true);
    });

    it('checks again after a conversation is created', async () => {
      const wrapper = mountTab();
      await flushPromises();
      getAttendance.mockClear();

      await wrapper.find('.criou').trigger('click');
      await flushPromises();

      expect(getAttendance).toHaveBeenCalledTimes(1);
    });

    it('does not ask when the ticket has no requester', async () => {
      mountTab([], null);
      await flushPromises();

      expect(getAttendance).not.toHaveBeenCalled();
    });
  });

  // "Abrir conversa": cria uma conversa com o solicitante, ja vinculada a este ticket.
  describe('abrir conversa', () => {
    it('offers the button, aimed at the requester and at THIS ticket', () => {
      const wrapper = mountTab();
      const compose = wrapper.find('.compose');

      expect(wrapper.text()).toContain('TICKET.DETAIL.OPEN_CONVERSATION');
      expect(compose.attributes('data-contact')).toBe('77');
      expect(compose.attributes('data-ticket')).toBe('5');
    });

    it('loads the requester into the contacts store, where the form reads it', () => {
      mountTab();

      expect(dispatch).toHaveBeenCalledWith('contacts/show', { id: 77 });
    });

    it('asks the page to reload the ticket once the conversation is created', async () => {
      const wrapper = mountTab();

      await wrapper.find('.criou').trigger('click');

      expect(wrapper.emitted('refresh')).toHaveLength(1);
    });

    it('says why there is no button when the ticket has no requester', () => {
      const wrapper = mountTab([], null);

      expect(wrapper.find('.compose').exists()).toBe(false);
      expect(wrapper.text()).toContain('TICKET.DETAIL.OPEN_CONVERSATION_NO_REQUESTER');
      expect(dispatch).not.toHaveBeenCalled();
    });
  });

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

  // Quem atende a conversa (ou atendeu, se ja foi encerrada) aparece na propria linha.
  describe('o atendente de cada conversa', () => {
    const conversa = (extra = {}) => ({
      id: 14,
      display_id: 2,
      inbox_name: 'Portal do Cliente',
      contact_name: 'Michelle',
      ...extra,
    });
    const atendente = wrapper => wrapper.find('[data-testid="conversation-attendant"]').text();

    it('names the agent attending an open conversation', () => {
      const wrapper = mountTab([conversa({ status: 'open', assignee_name: 'Maria' })]);

      expect(atendente(wrapper)).toContain('CONVERSATION_ASSIGNEE');
      expect(atendente(wrapper)).toContain('Maria');
    });

    it('says who handled a conversation that was already resolved', () => {
      const wrapper = mountTab([conversa({ status: 'resolved', assignee_name: 'Maria' })]);

      expect(atendente(wrapper)).toContain('CONVERSATION_ATTENDED_BY');
      expect(atendente(wrapper)).toContain('Maria');
    });

    it('says there is no agent when nobody is assigned', () => {
      const wrapper = mountTab([conversa({ status: 'open', assignee_name: null })]);

      expect(atendente(wrapper)).toContain('CONVERSATION_NO_ASSIGNEE');
    });

    it('translates the status instead of showing the raw word', () => {
      const wrapper = mountTab([conversa({ status: 'resolved', assignee_name: 'Maria' })]);

      expect(wrapper.text()).toContain('CONVERSATION_STATUS.RESOLVED');
      expect(wrapper.text()).not.toContain(' resolved ');
    });
  });

  // The regression this pins: the dashboard route and the conversations API
  // both resolve on display_id, so navigating with the primary key opens
  // somebody else's conversation.
  it('navigates by display_id, not the internal id', async () => {
    const wrapper = mountTab([
      { id: 14, display_id: 2, status: 'open', inbox_name: 'Suporte Web' },
    ]);
    // The first buttons are the Interna/Cliente switch and "Abrir conversa"; the
    // conversation link is the one that carries the conversation number.
    const link = wrapper
      .findAll('button')
      .find(b => !b.attributes('data-channel') && b.text().includes('#2'));
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
