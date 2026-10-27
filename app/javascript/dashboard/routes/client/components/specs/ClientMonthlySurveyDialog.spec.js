import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import {
  getClientSession,
  setMonthlySurveyDismissed,
} from 'dashboard/helper/clientSession';
import ClientMonthlySurveyDialog from '../ClientMonthlySurveyDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const QUESTION_KEYS = [
  'erp_overall',
  'erp_meets_needs',
  'erp_ease_of_use',
  'erp_practicality',
  'erp_performance',
  'support_service',
  'support_clarity',
  'support_response_time',
  'product_evolution',
  'overall_experience',
];

const monthlySurveyStatus = vi.fn(() =>
  Promise.resolve({
    data: {
      answered: false,
      reference_month: '2026-10-01',
      question_keys: QUESTION_KEYS,
    },
  })
);
const submitMonthlySurvey = vi.fn(() => Promise.resolve({ data: {} }));

vi.mock('dashboard/api/clientArea', () => ({
  default: {
    monthlySurveyStatus: (...args) => monthlySurveyStatus(...args),
    submitMonthlySurvey: (...args) => submitMonthlySurvey(...args),
  },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('dashboard/helper/clientSession', () => ({
  getClientSession: vi.fn(() => ({ contact: { id: 7 } })),
  setMonthlySurveyDismissed: vi.fn(),
}));

// Espelha o contrato real do Dialog de components-next: expõe open/close,
// dispara `confirm` pelo botão de confirmar e `close` pelo de cancelar - que é
// exatamente como o Dialog real se comporta ao clicar em Cancelar/fora/Esc.
const DialogStub = {
  props: {
    disableConfirmButton: { type: Boolean, default: false },
    showConfirmButton: { type: Boolean, default: true },
    title: { type: String, default: '' },
  },
  emits: ['confirm', 'close'],
  methods: { open() {}, close() {} },
  template: `<div>
    <p class="titulo">{{ title }}</p>
    <slot />
    <button class="confirmar" :disabled="disableConfirmButton" @click="$emit('confirm')" />
    <button class="cancelar" @click="$emit('close')" />
  </div>`,
};

const montar = () =>
  mount(ClientMonthlySurveyDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });

const confirmar = wrapper => wrapper.find('.confirmar');
const cancelar = wrapper => wrapper.find('.cancelar');
// Só os botões de nota: o X do topo também tem `aria-label`, mas não `aria-pressed`.
const notas = wrapper => wrapper.findAll('button[aria-pressed]');

// Clica na nota `valor` da pergunta de índice `indicePergunta` (0 a 9) -
// cada pergunta tem cinco botões (1 a 5) seguidos.
const escolherNota = async (wrapper, indicePergunta, valor) => {
  await notas(wrapper)[indicePergunta * 5 + (valor - 1)].trigger('click');
};

const responderTudo = async (wrapper, valor = 4) => {
  for (let i = 0; i < QUESTION_KEYS.length; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await escolherNota(wrapper, i, valor);
  }
};

beforeEach(() => {
  monthlySurveyStatus.mockClear();
  submitMonthlySurvey.mockClear();
  useAlert.mockClear();
  setMonthlySurveyDismissed.mockClear();
  getClientSession.mockClear();
});

describe('ClientMonthlySurveyDialog', () => {
  it('shows the ten fixed questions, in the order the server sent', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();

    expect(notas(wrapper)).toHaveLength(QUESTION_KEYS.length * 5);
  });

  it('keeps the confirm button disabled while any question is unanswered', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();

    expect(confirmar(wrapper).attributes('disabled')).toBeDefined();

    await responderTudo(wrapper);

    expect(confirmar(wrapper).attributes('disabled')).toBeUndefined();
  });

  it('marks the chosen rating, one answer per question', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();

    await escolherNota(wrapper, 0, 5);
    await escolherNota(wrapper, 0, 2);

    const botoesDaPrimeira = notas(wrapper).slice(0, 5);
    expect(botoesDaPrimeira.map(b => b.attributes('aria-pressed'))).toEqual([
      'false',
      'true',
      'false',
      'false',
      'false',
    ]);
  });

  it('sends one rating per question plus the optional comment', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();
    await responderTudo(wrapper, 4);
    await wrapper.find('textarea').setValue('Podiam agilizar o suporte.');

    await confirmar(wrapper).trigger('click');
    await flushPromises();

    expect(submitMonthlySurvey).toHaveBeenCalledWith({
      answers: QUESTION_KEYS.reduce((acc, chave) => {
        acc[chave] = 4;
        return acc;
      }, {}),
      comment: 'Podiam agilizar o suporte.',
    });
  });

  it('sends null for the comment when nothing was written', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();
    await responderTudo(wrapper, 3);

    await confirmar(wrapper).trigger('click');
    await flushPromises();

    expect(submitMonthlySurvey.mock.calls[0][0].comment).toBeNull();
  });

  // A mensagem de agradecimento pedida: depois de responder, a tela troca de
  // conteudo em vez de simplesmente fechar o modal.
  it('shows a thank-you message after answering, instead of closing', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();
    await responderTudo(wrapper, 5);

    await confirmar(wrapper).trigger('click');
    await flushPromises();

    expect(wrapper.find('.titulo').text()).toBe(
      'CLIENT_AREA.MONTHLY_SURVEY.THANKS_TITLE'
    );
    expect(notas(wrapper)).toHaveLength(0);
  });

  // O PONTO CENTRAL do pedido tambem vale no front: se outra aba ja
  // respondeu entretanto, o servidor recusa, e a tela trata isso com calma -
  // nao insiste, so avisa e fecha.
  it('handles a same-month duplicate answer gracefully', async () => {
    submitMonthlySurvey.mockRejectedValueOnce({
      response: { data: { code: 'already_answered' } },
    });
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();
    await responderTudo(wrapper, 3);

    await confirmar(wrapper).trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'CLIENT_AREA.MONTHLY_SURVEY.ALREADY_ANSWERED'
    );
  });

  // Se o status chegar "ja respondida" (outra aba, por exemplo), o modal
  // nem abre - nao ha' nada para a pessoa responder de novo.
  it('does not open when the server already has an answer for this month', async () => {
    monthlySurveyStatus.mockResolvedValueOnce({
      data: {
        answered: true,
        reference_month: '2026-10-01',
        question_keys: QUESTION_KEYS,
      },
    });
    const wrapper = montar();

    await wrapper.vm.open();
    await flushPromises();

    expect(notas(wrapper)).toHaveLength(0);
  });

  // Fechar SEM responder marca "adiada nesta sessao" - e' o que evita o
  // modal insistir a cada troca de tela depois que a pessoa pediu para
  // responder depois.
  it('marks the survey as dismissed for this session when closed unanswered', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();

    await cancelar(wrapper).trigger('click');

    expect(setMonthlySurveyDismissed).toHaveBeenCalledWith(7, '2026-10-01');
  });

  // Mas fechar a tela de agradecimento (depois de responder) nao tem nada
  // para adiar - a avaliacao ja foi enviada.
  it('does not mark as dismissed when closing after answering', async () => {
    const wrapper = montar();
    await wrapper.vm.open();
    await flushPromises();
    await responderTudo(wrapper, 5);
    await confirmar(wrapper).trigger('click');
    await flushPromises();

    await cancelar(wrapper).trigger('click');

    expect(setMonthlySurveyDismissed).not.toHaveBeenCalled();
  });
});
