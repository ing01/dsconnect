import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';

import TicketTimeEntriesTab from '../TicketTimeEntriesTab.vue';

// A aba de apontamentos: lista, edita (horas e minutos) e remove o que ja foi lancado.
const entries = ref([]);
const dispatch = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/store/utils/api', () => ({
  parseAPIErrorResponse: () => '',
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    getters: {
      'ticketTimeEntries/getEntriesByTicket': () => entries.value,
    },
    dispatch: (...args) => dispatch(...args),
  }),
}));

const ButtonStub = {
  inheritAttrs: false,
  props: ['label'],
  template: '<button type="button" v-bind="$attrs">{{ label }}</button>',
};

const montar = (props = {}) =>
  mount(TicketTimeEntriesTab, {
    props: { ticketId: 10, ...props },
    global: {
      stubs: {
        NextButton: ButtonStub,
        Icon: true,
        TicketTimerCard: {
          props: ['defaultCategory'],
          template:
            '<div data-testid="timer-card" :data-category="defaultCategory" />',
        },
      },
    },
  });

const find = (wrapper, id) => wrapper.find(`[data-testid="${id}"]`);

describe('TicketTimeEntriesTab', () => {
  beforeEach(() => {
    entries.value = [
      {
        id: 1,
        hours: '1.5',
        category: 'desenvolvimento',
        worked_on: '2026-11-10',
        note: 'tela de pedidos',
        user_name: 'Joao',
      },
    ];
    dispatch.mockReset();
    dispatch.mockResolvedValue({});
  });

  it('mostra o cronometro acima da lista', () => {
    expect(find(montar(), 'timer-card').exists()).toBe(true);
  });

  it('escreve o tempo do apontamento em horas e minutos', () => {
    expect(find(montar(), 'entry-row').text()).toContain('1h30min');
  });

  it('editar abre horas e minutos ja preenchidos', async () => {
    const wrapper = montar();

    await find(wrapper, 'entry-edit').trigger('click');

    expect(find(wrapper, 'edit-hours').element.value).toBe('1');
    expect(find(wrapper, 'edit-minutes').element.value).toBe('30');
  });

  it('salvar manda as horas em decimal e o resto do apontamento', async () => {
    const wrapper = montar();
    await find(wrapper, 'entry-edit').trigger('click');

    await find(wrapper, 'edit-hours').setValue(2);
    await find(wrapper, 'edit-minutes').setValue(15);
    await find(wrapper, 'entry-edit-form').trigger('submit');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/update', {
      ticketId: 10,
      entryId: 1,
      hours: 2.25,
      category: 'desenvolvimento',
      worked_on: '2026-11-10',
      note: 'tela de pedidos',
    });
    expect(find(wrapper, 'entry-edit-form').exists()).toBe(false);
  });

  it('nao salva um apontamento zerado', async () => {
    const wrapper = montar();
    await find(wrapper, 'entry-edit').trigger('click');

    await find(wrapper, 'edit-hours').setValue(0);
    await find(wrapper, 'edit-minutes').setValue(0);
    await find(wrapper, 'entry-edit-form').trigger('submit');

    expect(dispatch).not.toHaveBeenCalledWith(
      'ticketTimeEntries/update',
      expect.anything()
    );
  });

  it('remover apaga o apontamento', async () => {
    const wrapper = montar();

    await find(wrapper, 'entry-delete').trigger('click');

    expect(dispatch).toHaveBeenCalledWith('ticketTimeEntries/delete', {
      ticketId: 10,
      entryId: 1,
    });
  });

  describe('a categoria vem da Mesa do ticket', () => {
    it('Mesa de Desenvolvimento: o formulario e o cronometro ja vem em Desenvolvimento', () => {
      const wrapper = montar({ teamName: 'Desenvolvimento' });

      expect(find(wrapper, 'entry-category').element.value).toBe(
        'desenvolvimento'
      );
      expect(find(wrapper, 'timer-card').attributes('data-category')).toBe(
        'desenvolvimento'
      );
    });

    it('Mesa de Implantacao: vem em Implantacao', () => {
      const wrapper = montar({ teamName: 'Implantação' });

      expect(find(wrapper, 'entry-category').element.value).toBe('implantacao');
      expect(find(wrapper, 'timer-card').attributes('data-category')).toBe(
        'implantacao'
      );
    });

    it('Mesa que nao e nenhuma das duas: fica o padrao (Implantacao)', () => {
      const wrapper = montar({ teamName: 'Suporte' });

      expect(find(wrapper, 'entry-category').element.value).toBe('implantacao');
    });

    it('se o ticket muda de Mesa, a categoria acompanha', async () => {
      const wrapper = montar({ teamName: 'Implantação' });

      await wrapper.setProps({ teamName: 'Desenvolvimento' });

      expect(find(wrapper, 'entry-category').element.value).toBe(
        'desenvolvimento'
      );
    });

    it('se a pessoa escolheu outra categoria, a escolha dela vale', async () => {
      const wrapper = montar({ teamName: 'Implantação' });
      await find(wrapper, 'entry-category').setValue('dev_geral');

      await wrapper.setProps({ teamName: 'Desenvolvimento' });

      expect(find(wrapper, 'entry-category').element.value).toBe('dev_geral');
    });
  });

  describe('os tempos batem', () => {
    it('a dica ao passar o mouse mostra o relogio exato, e nao horas decimais', () => {
      entries.value = [{ ...entries.value[0], hours: '0.0333' }];

      const wrapper = montar();

      expect(find(wrapper, 'entry-row').text()).toContain('2min');
      expect(
        find(wrapper, 'entry-row').find('[title="00:02:00"]').exists()
      ).toBe(true);
    });

    it('o total soma o que foi apontado: 1 minuto + 2 minutos = 3 minutos', () => {
      entries.value = [
        { ...entries.value[0], id: 1, hours: '0.0333' },
        { ...entries.value[0], id: 2, hours: '0.0167' },
      ];

      const wrapper = montar();

      expect(wrapper.text()).toContain(
        'TICKET.DETAIL.TIME_ENTRIES.TOTAL: 3min'
      );
    });

    it('abrir e salvar sem mexer nas horas nao muda o tempo (guarda os segundos)', async () => {
      entries.value = [{ ...entries.value[0], hours: '0.0353' }]; // 2min07s
      const wrapper = montar();
      await find(wrapper, 'entry-edit').trigger('click');

      await find(wrapper, 'entry-edit-form').trigger('submit');
      await flushPromises();

      const [, payload] = dispatch.mock.calls.find(
        ([name]) => name === 'ticketTimeEntries/update'
      );
      expect(payload).not.toHaveProperty('hours');
      expect(payload).toMatchObject({
        category: 'desenvolvimento',
        note: 'tela de pedidos',
      });
    });
  });
});
