import { mount } from '@vue/test-utils';
import TicketMesaCardLabel from '../TicketMesaCardLabel.vue';

describe('TicketMesaCardLabel', () => {
  it('shows the Mesa name of the linked ticket', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: { chat: { ticket_team_name: 'Suporte N2' } },
    });

    expect(wrapper.text()).toContain('Suporte N2');
  });

  it('renders nothing without a linked ticket', () => {
    const wrapper = mount(TicketMesaCardLabel, {
      props: { chat: { ticket_team_name: null } },
    });

    expect(wrapper.text()).toBe('');
  });
});
