import { shallowMount } from '@vue/test-utils';
import TicketOverviewTab from '../TicketOverviewTab.vue';
import TicketTimerCard from '../TicketTimerCard.vue';

// O cronometro do apontamento aparece na primeira aba so na Mesa de
// Desenvolvimento, e na categoria da Mesa.
const montar = props =>
  shallowMount(TicketOverviewTab, {
    props: { ticket: { id: 7, team_name: 'Desenvolvimento' }, ...props },
    global: { mocks: { $t: key => key } },
  });

describe('TicketOverviewTab - cronometro do apontamento', () => {
  it('aparece na Mesa de Desenvolvimento, na categoria da Mesa', () => {
    const timer = montar({ isDevMesa: true }).findComponent(TicketTimerCard);

    expect(timer.exists()).toBe(true);
    expect(timer.props()).toMatchObject({
      ticketId: 7,
      defaultCategory: 'desenvolvimento',
    });
  });

  it('nao aparece nas demais Mesas', () => {
    expect(montar().findComponent(TicketTimerCard).exists()).toBe(false);
  });
});
