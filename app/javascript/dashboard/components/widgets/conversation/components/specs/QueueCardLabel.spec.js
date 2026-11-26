import { mount } from '@vue/test-utils';
import QueueCardLabel from '../QueueCardLabel.vue';

describe('QueueCardLabel', () => {
  it('shows the queue the conversation is in', () => {
    const wrapper = mount(QueueCardLabel, {
      props: { chat: { meta: { queue: { name: 'Comercial' } } } },
    });

    expect(wrapper.text()).toContain('Comercial');
  });

  // O selo e' so' da fila: a Mesa do ticket vinculado e o Time da conversa nao
  // aparecem mais nele.
  it('ignores the linked ticket Mesa and the conversation Time', () => {
    const wrapper = mount(QueueCardLabel, {
      props: {
        chat: {
          ticket_team_name: 'Suporte',
          meta: { team: { name: 'Suporte' }, queue: { name: 'Especialista' } },
        },
      },
    });

    expect(wrapper.text()).toContain('Especialista');
    expect(wrapper.text()).not.toContain('Suporte');
  });

  it('renders nothing when the conversation has no queue', () => {
    const wrapper = mount(QueueCardLabel, {
      props: {
        chat: {
          ticket_team_name: 'Suporte',
          meta: { team: { name: 'Suporte' } },
        },
      },
    });

    expect(wrapper.text()).toBe('');
  });
});
