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
        RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
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

  it('mostra de onde cada chat do historico foi aberto, com link', () => {
    const wrapper = montar({
      showHistory: true,
      threads: [
        {
          id: 1,
          title: 'A',
          created_at: 1790000000,
          conversation_display_id: 12,
          ticket: { id: null, display_id: null },
        },
        {
          id: 2,
          title: 'B',
          created_at: 1790000000,
          conversation_display_id: null,
          ticket: { id: 7, display_id: 31 },
        },
        {
          id: 3,
          title: 'C',
          created_at: 1790000000,
          conversation_display_id: null,
          ticket: { id: null, display_id: null },
        },
      ],
    });

    const links = wrapper.findAll('a');
    expect(links).toHaveLength(2);
    expect(links[0].attributes('href')).toContain('/conversations/12');
    expect(links[0].text()).toContain('ORIGIN_CONVERSATION');
    expect(links[1].attributes('href')).toContain('/tickets/7');
    expect(links[1].text()).toContain('ORIGIN_TICKET');
  });

  it('mostra a origem na conversa aberta', () => {
    const wrapper = montar({
      messages: [mensagem(1, 'user', 'oi'), mensagem(2, 'assistant', 'ola')],
      thread: { id: 9, conversation_display_id: 5, ticket: { id: null } },
    });

    expect(wrapper.find('a').attributes('href')).toContain('/conversations/5');
  });

  it('exclui uma conversa do historico so depois de confirmar', async () => {
    const wrapper = montar({
      showHistory: true,
      threads: [{ id: 5, title: 'A', created_at: 1790000000 }],
    });
    const lixeira = wrapper.find(
      'button[aria-label="CAPTAIN.COPILOT.HISTORY.DELETE"]'
    );

    await lixeira.trigger('click');
    expect(wrapper.emitted('deleteThread')).toBeUndefined();
    expect(wrapper.text()).toContain('DELETE_CONFIRM');

    const sim = wrapper
      .findAll('button')
      .find(button => button.text() === 'CAPTAIN.COPILOT.HISTORY.DELETE_YES');
    await sim.trigger('click');

    expect(wrapper.emitted('deleteThread')[0][0].id).toBe(5);
  });

  it('cancelar a exclusao nao apaga nada', async () => {
    const wrapper = montar({
      showHistory: true,
      threads: [{ id: 5, title: 'A', created_at: 1790000000 }],
    });
    await wrapper
      .find('button[aria-label="CAPTAIN.COPILOT.HISTORY.DELETE"]')
      .trigger('click');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CAPTAIN.COPILOT.HISTORY.DELETE_NO')
      .trigger('click');

    expect(wrapper.emitted('deleteThread')).toBeUndefined();
    expect(wrapper.text()).not.toContain('DELETE_CONFIRM');
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
