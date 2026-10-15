import { mount } from '@vue/test-utils';
import EditAgent from '../EditAgent.vue';

const { dispatch, holder } = vi.hoisted(() => ({
  dispatch: vi.fn().mockResolvedValue({}),
  holder: {},
}));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.uiFlags = ref({ isUpdating: false });
  holder.customRoles = ref([]);
  return {
    useStore: () => ({ dispatch }),
    useMapGetter: key => {
      if (key === 'agents/getUIFlags') return holder.uiFlags;
      if (key === 'customRole/getCustomRoles') return holder.customRoles;
      return ref(null);
    },
  };
});

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const baseProps = {
  id: 7,
  name: 'Guilherme Vasconcelos',
  availability: 'online',
  type: 'agent',
};

const mountComponent = (props = {}) =>
  mount(EditAgent, {
    props: { ...baseProps, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: { 'woot-modal-header': true },
    },
  });

// Pedido: horario de almoco por agente - 20 min antes do inicio a
// distribuicao automatica para de atribuir, volta normalmente no fim.
describe('EditAgent lunch break', () => {
  beforeEach(() => {
    dispatch.mockClear();
  });

  it('starts with both times empty when the agent has no lunch break configured', () => {
    const wrapper = mountComponent();

    const times = wrapper.findAll('input[type="time"]');
    expect(times[0].element.value).toBe('');
    expect(times[1].element.value).toBe('');
  });

  it('pre-fills the times from the hour/minute props already saved', () => {
    const wrapper = mountComponent({
      lunchStartHour: 11,
      lunchStartMinutes: 0,
      lunchEndHour: 13,
      lunchEndMinutes: 30,
    });

    const times = wrapper.findAll('input[type="time"]');
    expect(times[0].element.value).toBe('11:00');
    expect(times[1].element.value).toBe('13:30');
  });

  it('sends the times split back into hour/minutes on submit', async () => {
    const wrapper = mountComponent();

    const times = wrapper.findAll('input[type="time"]');
    await times[0].setValue('11:00');
    await times[1].setValue('13:00');
    await wrapper.find('form').trigger('submit');

    expect(dispatch).toHaveBeenCalledWith(
      'agents/update',
      expect.objectContaining({
        lunch_start_hour: 11,
        lunch_start_minutes: 0,
        lunch_end_hour: 13,
        lunch_end_minutes: 0,
      })
    );
  });

  it('sends all 4 fields as null when both times are cleared, to erase a saved lunch break', async () => {
    const wrapper = mountComponent({
      lunchStartHour: 11,
      lunchStartMinutes: 0,
      lunchEndHour: 13,
      lunchEndMinutes: 0,
    });

    const times = wrapper.findAll('input[type="time"]');
    await times[0].setValue('');
    await times[1].setValue('');
    await wrapper.find('form').trigger('submit');

    expect(dispatch).toHaveBeenCalledWith(
      'agents/update',
      expect.objectContaining({
        lunch_start_hour: null,
        lunch_start_minutes: null,
        lunch_end_hour: null,
        lunch_end_minutes: null,
      })
    );
  });

  it('blocks submit when only one of the two times is filled', async () => {
    const wrapper = mountComponent();

    const times = wrapper.findAll('input[type="time"]');
    await times[0].setValue('11:00');
    await wrapper.find('form').trigger('submit');

    expect(dispatch).not.toHaveBeenCalled();
  });

  it('blocks submit when the end time is not after the start time', async () => {
    const wrapper = mountComponent();

    const times = wrapper.findAll('input[type="time"]');
    await times[0].setValue('13:00');
    await times[1].setValue('11:00');
    await wrapper.find('form').trigger('submit');

    expect(dispatch).not.toHaveBeenCalled();
  });
});
