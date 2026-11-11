import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';

import TicketTimerCard from '../TicketTimerCard.vue';

// O cronometro do apontamento: a tela so desenha o relogio; o tempo e' do servidor.
const timers = ref([]);
const dispatch = vi.fn();
const useAlert = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => useAlert(...args),
}));
vi.mock('dashboard/store/utils/api', () => ({
  parseAPIErrorResponse: () => '',
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    getters: { 'ticketTimeEntries/getTimersByTicket': () => timers.value },
    dispatch: (...args) => dispatch(...args),
  }),
}));

const ButtonStub = {
  inheritAttrs: false,
  props: ['label'],
  template: '<button type="button" v-bind="$attrs">{{ label }}</button>',
};

const montar = (props = {}) =>
  mount(TicketTimerCard, {
    props: { ticketId: 10, ...props },
    global: { stubs: { NextButton: ButtonStub, Icon: true } },
  });

const find = (wrapper, id) => wrapper.find(`[data-testid="${id}"]`);

describe('TicketTimerCard', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-11T12:00:00Z'));
    timers.value = [];
    dispatch.mockReset();
    dispatch.mockResolvedValue({});
    useAlert.mockReset();
  });

  afterEach(() => vi.useRealTimers());

  it('busca o cronometro do ticket ao abrir', () => {
    montar();

    expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/getTimers', 10);
  });

  describe('sem cronometro', () => {
    it('oferece escolher a categoria e iniciar', () => {
      const wrapper = montar();

      expect(find(wrapper, 'timer-start').exists()).toBe(true);
      expect(find(wrapper, 'timer-category').exists()).toBe(true);
      expect(find(wrapper, 'timer-clock').exists()).toBe(false);
    });

    it('ja vem na categoria da Mesa do ticket', () => {
      const wrapper = montar({ defaultCategory: 'desenvolvimento' });

      expect(find(wrapper, 'timer-category').element.value).toBe(
        'desenvolvimento'
      );
    });

    it('iniciar sem mexer na categoria usa a da Mesa', async () => {
      const wrapper = montar({ defaultCategory: 'desenvolvimento' });

      await find(wrapper, 'timer-start').trigger('click');

      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/startTimer', {
        ticketId: 10,
        category: 'desenvolvimento',
        note: '',
      });
    });

    it('se o ticket muda de Mesa, a categoria acompanha; se a pessoa escolheu, a escolha vale', async () => {
      const acompanha = montar({ defaultCategory: 'implantacao' });
      await acompanha.setProps({ defaultCategory: 'desenvolvimento' });
      expect(find(acompanha, 'timer-category').element.value).toBe(
        'desenvolvimento'
      );

      const escolheu = montar({ defaultCategory: 'implantacao' });
      await find(escolheu, 'timer-category').setValue('dev_geral');
      await escolheu.setProps({ defaultCategory: 'desenvolvimento' });
      expect(find(escolheu, 'timer-category').element.value).toBe('dev_geral');
    });

    it('iniciar manda a categoria e a observacao', async () => {
      const wrapper = montar();
      await find(wrapper, 'timer-category').setValue('desenvolvimento');
      await find(wrapper, 'timer-note').setValue('  tela de pedidos ');

      await find(wrapper, 'timer-start').trigger('click');

      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/startTimer', {
        ticketId: 10,
        category: 'desenvolvimento',
        note: 'tela de pedidos',
      });
    });
  });

  describe('com cronometro correndo', () => {
    beforeEach(() => {
      timers.value = [
        {
          id: 5,
          status: 'running',
          category: 'desenvolvimento',
          note: 'tela de pedidos',
          elapsed_seconds: 3661, // 01:01:01 quando a tela recebeu
          receivedAt: Date.now(),
        },
      ];
    });

    it('mostra o relogio a partir do que o servidor contou', () => {
      const wrapper = montar();

      expect(find(wrapper, 'timer-clock').text()).toBe('01:01:01');
      expect(find(wrapper, 'timer-pause').exists()).toBe(true);
      expect(find(wrapper, 'timer-resume').exists()).toBe(false);
    });

    it('o relogio anda de segundo em segundo', async () => {
      const wrapper = montar();

      vi.advanceTimersByTime(5000);
      await wrapper.vm.$nextTick();

      expect(find(wrapper, 'timer-clock').text()).toBe('01:01:06');
    });

    it('pausar manda o id do cronometro', async () => {
      const wrapper = montar();

      await find(wrapper, 'timer-pause').trigger('click');

      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/pauseTimer', {
        ticketId: 10,
        timerId: 5,
      });
    });

    it('finalizar lanca o tempo e avisa', async () => {
      dispatch.mockImplementation(async name =>
        name === 'ticketTimeEntries/finishTimer' ? { id: 77 } : {}
      );
      const wrapper = montar();

      await find(wrapper, 'timer-finish').trigger('click');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/finishTimer', {
        ticketId: 10,
        timerId: 5,
      });
      expect(useAlert).toHaveBeenCalledWith(
        'TICKET.DETAIL.TIME_ENTRIES.TIMER.FINISHED'
      );
    });

    it('descartar pede confirmacao antes de apagar', async () => {
      const wrapper = montar();

      await find(wrapper, 'timer-discard').trigger('click');
      expect(dispatch).not.toHaveBeenCalledWith(
        'ticketTimeEntries/discardTimer',
        expect.anything()
      );

      await find(wrapper, 'timer-discard').trigger('click');
      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/discardTimer', {
        ticketId: 10,
        timerId: 5,
      });
    });

    it('um erro do servidor aparece como aviso', async () => {
      dispatch.mockImplementation(async name => {
        if (name === 'ticketTimeEntries/pauseTimer') throw new Error('x');
        return {};
      });
      const wrapper = montar();

      await find(wrapper, 'timer-pause').trigger('click');
      await flushPromises();

      expect(useAlert).toHaveBeenCalledWith(
        'TICKET.DETAIL.TIME_ENTRIES.TIMER.ERROR'
      );
    });
  });

  describe('com cronometro pausado', () => {
    beforeEach(() => {
      timers.value = [
        {
          id: 5,
          status: 'paused',
          category: 'implantacao',
          note: null,
          elapsed_seconds: 600,
          receivedAt: Date.now(),
        },
      ];
    });

    it('o relogio fica parado e oferece continuar', async () => {
      const wrapper = montar();

      vi.advanceTimersByTime(30000);
      await wrapper.vm.$nextTick();

      expect(find(wrapper, 'timer-clock').text()).toBe('00:10:00');
      expect(find(wrapper, 'timer-resume').exists()).toBe(true);
      expect(find(wrapper, 'timer-pause').exists()).toBe(false);
    });

    it('continuar manda o id do cronometro', async () => {
      const wrapper = montar();

      await find(wrapper, 'timer-resume').trigger('click');

      expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/resumeTimer', {
        ticketId: 10,
        timerId: 5,
      });
    });
  });
});
