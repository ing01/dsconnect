import { mount } from '@vue/test-utils';

import CopilotAssistantMessage from '../CopilotAssistantMessage.vue';

// O agente avalia a resposta do DueBot: polegar para cima grava na hora, polegar para
// baixo pede motivo e comentario antes de enviar.
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useTrack: vi.fn() }));

const ButtonStub = {
  inheritAttrs: false,
  props: ['label', 'icon'],
  template: '<button type="button" v-bind="$attrs">{{ label }}</button>',
};

const montar = (props = {}) =>
  mount(CopilotAssistantMessage, {
    props: {
      message: { content: 'Va em Fiscal > Emissao.' },
      conversationInboxType: 'Channel::Api',
      messageId: 42,
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      directives: { 'dompurify-html': () => {} },
      stubs: { Button: ButtonStub },
    },
  });

describe('CopilotAssistantMessage, feedback', () => {
  it('mostra os dois polegares na resposta', () => {
    const wrapper = montar();

    expect(wrapper.find('[data-testid="feedback-up"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="feedback-down"]').exists()).toBe(true);
  });

  it('nao oferece avaliar quando a resposta veio vazia (erro)', () => {
    const wrapper = montar({ message: { content: '' } });

    expect(wrapper.find('[data-testid="feedback-up"]').exists()).toBe(false);
  });

  it('nao oferece avaliar sem o id da mensagem', () => {
    const wrapper = montar({ messageId: null });

    expect(wrapper.find('[data-testid="feedback-up"]').exists()).toBe(false);
  });

  it('polegar para cima envia a avaliacao positiva na hora, sem formulario', async () => {
    const wrapper = montar();

    await wrapper.find('[data-testid="feedback-up"]').trigger('click');

    expect(wrapper.emitted('rate')[0][0]).toEqual({
      messageId: 42,
      rating: 'positive',
    });
    expect(wrapper.find('[data-testid="feedback-form"]').exists()).toBe(false);
  });

  it('polegar para cima de novo desfaz a avaliacao positiva', async () => {
    const wrapper = montar({ feedback: { rating: 'positive' } });

    await wrapper.find('[data-testid="feedback-up"]').trigger('click');

    expect(wrapper.emitted('clearRate')[0][0]).toEqual({ messageId: 42 });
    expect(wrapper.emitted('rate')).toBeUndefined();
  });

  it('polegar para baixo abre o formulario e so envia ao confirmar', async () => {
    const wrapper = montar();

    await wrapper.find('[data-testid="feedback-down"]').trigger('click');
    expect(wrapper.find('[data-testid="feedback-form"]').exists()).toBe(true);
    expect(wrapper.emitted('rate')).toBeUndefined();

    await wrapper
      .findAll('[data-testid="feedback-form"] button')[0]
      .trigger('click'); // motivo
    await wrapper
      .find('[data-testid="feedback-comment"]')
      .setValue('  O menu e outro.  ');
    await wrapper.find('[data-testid="feedback-send"]').trigger('click');

    expect(wrapper.emitted('rate')[0][0]).toEqual({
      messageId: 42,
      rating: 'negative',
      reason: 'wrong_answer',
      comment: 'O menu e outro.',
    });
    expect(wrapper.find('[data-testid="feedback-form"]').exists()).toBe(false);
  });

  it('permite enviar o polegar para baixo sem motivo nem comentario', async () => {
    const wrapper = montar();

    await wrapper.find('[data-testid="feedback-down"]').trigger('click');
    await wrapper.find('[data-testid="feedback-send"]').trigger('click');

    expect(wrapper.emitted('rate')[0][0]).toEqual({
      messageId: 42,
      rating: 'negative',
      reason: undefined,
      comment: undefined,
    });
  });

  it('reabre o formulario com o que ja foi enviado, para editar', async () => {
    const wrapper = montar({
      feedback: { rating: 'negative', reason: 'outdated', comment: 'Mudou.' },
    });

    await wrapper.find('[data-testid="feedback-down"]').trigger('click');

    expect(wrapper.find('[data-testid="feedback-comment"]').element.value).toBe(
      'Mudou.'
    );
  });

  it('agradece depois de avaliada e marca o polegar escolhido', () => {
    const wrapper = montar({ feedback: { rating: 'positive' } });

    expect(wrapper.find('[data-testid="feedback-thanks"]').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="feedback-up"]').attributes('aria-pressed')
    ).toBe('true');
    expect(
      wrapper.find('[data-testid="feedback-down"]').attributes('aria-pressed')
    ).toBe('false');
  });
});
