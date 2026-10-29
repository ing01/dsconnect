import { mount } from '@vue/test-utils';

import Copilot from '../Copilot.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRoute: () => ({ params: {} }) }));
vi.mock('dashboard/composables', () => ({ useTrack: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings: vi.fn() }),
}));

const mensagem = (id, message_type, content = '') => ({
  id,
  message_type,
  message: { content, reasoning: 'passo interno' },
});

const montar = (props = {}) =>
  mount(Copilot, {
    props: {
      conversationInboxType: 'Channel::Api',
      assistants: [{ id: 1 }],
      activeAssistant: { id: 1 },
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: {
        SidebarActionsHeader: true,
        CopilotInput: true,
        CopilotAssistantMessage: { template: '<p class="resposta" />' },
        CopilotAgentMessage: { template: '<p class="pergunta" />' },
        RouterLink: true,
      },
    },
  });

describe('Copilot (DueBot)', () => {
  it('nao exibe as acoes/etapas da IA, so o aviso de espera', () => {
    const wrapper = montar({
      messages: [
        mensagem(1, 'user', 'oi'),
        mensagem(2, 'assistant_thinking', 'consultando'),
      ],
    });

    expect(wrapper.text()).not.toContain('SHOW_STEPS');
    expect(wrapper.text()).not.toContain('passo interno');
    expect(wrapper.text()).toContain('CAPTAIN.COPILOT.LOADER_PHRASES.ONE');
  });

  it('some o aviso de espera quando a resposta chega', () => {
    const wrapper = montar({
      messages: [
        mensagem(1, 'user', 'oi'),
        mensagem(2, 'assistant_thinking'),
        mensagem(3, 'assistant', 'ola'),
      ],
    });

    expect(wrapper.find('.resposta').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('LOADER_PHRASES');
  });

  it('mostra o historico no lugar da conversa e esconde o campo de envio', async () => {
    const wrapper = montar({
      showHistory: true,
      threads: [{ id: 5, title: 'Como emitir nota?', created_at: 1790000000 }],
    });

    expect(wrapper.text()).toContain('Como emitir nota?');
    expect(wrapper.findComponent({ name: 'CopilotInput' }).exists()).toBe(
      false
    );

    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('selectThread')[0][0].id).toBe(5);
  });
});
