import { shallowMount } from '@vue/test-utils';

import CopilotEmptyState from '../CopilotEmptyState.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
}));

const mountComponent = (props = {}) =>
  shallowMount(CopilotEmptyState, {
    props: { hasAssistants: true, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: { RouterLink: true },
    },
  });

describe('CopilotEmptyState', () => {
  it('nao mostra mais a lista de comandos prontos', () => {
    const wrapper = mountComponent();

    expect(wrapper.findAll('button')).toHaveLength(0);
    expect(wrapper.text()).not.toContain('TRY_THESE_PROMPTS');
  });

  it('usa o texto de colaborador por padrao', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('CAPTAIN.COPILOT.KICK_OFF_MESSAGE');
    expect(wrapper.text()).not.toContain('KICK_OFF_MESSAGE_CLIENT');
  });

  it('usa o texto de cliente quando o perfil e cliente', () => {
    const wrapper = mountComponent({ audience: 'client' });

    expect(wrapper.text()).toContain('CAPTAIN.COPILOT.KICK_OFF_MESSAGE_CLIENT');
  });
});
