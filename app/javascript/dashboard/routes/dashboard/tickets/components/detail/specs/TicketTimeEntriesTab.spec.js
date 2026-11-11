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

const montar = () =>
  mount(TicketTimeEntriesTab, {
    props: { ticketId: 10 },
    global: {
      stubs: {
        NextButton: ButtonStub,
        Icon: true,
        TicketTimerCard: { template: '<div data-testid="timer-card" />' },
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
});
