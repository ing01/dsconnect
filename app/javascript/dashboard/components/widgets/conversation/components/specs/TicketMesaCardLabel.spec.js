import { mount } from '@vue/test-utils';
import TicketMesaCardLabel from '../TicketMesaCardLabel.vue';

describe('TicketMesaCardLabel', () => {
  it('shows the Mesa name of the linked ticket', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: { chat: { ticket_team_name: 'Suporte N2' } },
    });

    expect(wrapper.text()).toContain('Suporte N2');
  });

  // O caso comum: a conversa quase nunca tem um ticket vinculado (isso so
  // acontece em fluxos pontuais), mas pode ter um Time nativo atribuido pelo
  // menu "Atribuir Time" - sem este fallback, o rotulo quase nunca aparecia.
  it('falls back to the conversation’s own Time when there is no linked ticket', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: {
        chat: { ticket_team_name: null, meta: { team: { name: 'Suporte' } } },
      },
    });

    expect(wrapper.text()).toContain('Suporte');
  });

  it('prefers the linked ticket’s Mesa over the conversation’s Time when both exist', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: {
        chat: {
          ticket_team_name: 'Suporte N2',
          meta: { team: { name: 'Comercial' } },
        },
      },
    });

    expect(wrapper.text()).toContain('Suporte N2');
    expect(wrapper.text()).not.toContain('Comercial');
  });

  it('renders nothing without a linked ticket or a Time assigned to the conversation', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: { chat: { ticket_team_name: null } },
    });

    expect(wrapper.text()).toBe('');
  });
});
