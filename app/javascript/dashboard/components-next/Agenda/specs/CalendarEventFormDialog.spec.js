import { mount } from '@vue/test-utils';
import CalendarEventFormDialog from '../CalendarEventFormDialog.vue';

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  const teamMembersRef = ref(() => []);
  return {
    useStore: () => ({ dispatch: vi.fn(() => Promise.resolve()) }),
    useMapGetter: () => teamMembersRef,
  };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
// A lista de tickets pra "vincular" agora vem direto da API (nao mais do
// Vuex, que sobrescrevia a lista global usada pela pagina de detalhe do
// ticket - ver comentario no onMounted do componente). Mockado aqui pra nao
// bater no `axios` de verdade.
vi.mock('dashboard/api/tickets', () => ({
  default: { get: vi.fn(() => Promise.resolve({ data: { payload: [] } })) },
}));

// Um evento ja existente, com titulo preenchido - usado nos testes de envio,
// pra nao depender de digitar no `woot-input` (stubado, sem input de
// verdade) so' pra passar a validacao de titulo obrigatorio.
const EVENTO_BASE = {
  id: 1,
  title: 'Reuniao semanal',
  description: '',
  all_day: false,
  start_at: '2026-11-02T09:00:00.000Z',
  end_at: '2026-11-02T09:30:00.000Z',
  location: '',
  attendees: [],
  tickets: [],
  recurrence_frequency: 'single',
  recurrence_interval: null,
  recurrence_end_at: null,
  recurrence_count: null,
};

const montar = (props = {}) =>
  mount(CalendarEventFormDialog, {
    props: { teamId: 1, event: EVENTO_BASE, ...props },
    global: {
      stubs: {
        'woot-modal-header': true,
        'woot-input': true,
        NextButton: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template: `<button :disabled="isLoading" @click="$emit('click')">{{ label }}</button>`,
        },
        Avatar: true,
      },
    },
  });

const frequencySelect = wrapper => wrapper.find('select');
const radios = wrapper => wrapper.findAll('input[type="radio"]');
const salvar = wrapper =>
  wrapper.findAll('button').find(b => b.text() === 'AGENDA.FORM.SAVE');

describe('CalendarEventFormDialog recorrencia', () => {
  it('nao mostra intervalo/termino quando "nao se repete" (padrao)', () => {
    const wrapper = montar();

    expect(frequencySelect(wrapper).element.value).toBe('single');
    expect(wrapper.find('input[type="number"]').exists()).toBe(false);
    expect(radios(wrapper)).toHaveLength(0);
  });

  it('mostra intervalo e as 3 opcoes de termino ao escolher uma frequencia', async () => {
    const wrapper = montar();

    await frequencySelect(wrapper).setValue('weekly');

    expect(wrapper.find('input[type="number"]').exists()).toBe(true);
    expect(radios(wrapper)).toHaveLength(3);
  });

  it('desabilita o sub-campo da opcao de termino nao escolhida, habilita ao marcar', async () => {
    const wrapper = montar();
    await frequencySelect(wrapper).setValue('weekly');

    expect(
      wrapper.find('input[type="date"]').attributes('disabled')
    ).toBeDefined();

    await radios(wrapper)[1].setValue(); // 'on_date'

    expect(
      wrapper.find('input[type="date"]').attributes('disabled')
    ).toBeUndefined();
  });

  it('envia null nos dois campos de termino quando "nunca"', async () => {
    const wrapper = montar();
    await frequencySelect(wrapper).setValue('weekly');

    await salvar(wrapper).trigger('click');

    const enviado = wrapper.emitted('submit')[0][0];
    expect(enviado.recurrence_frequency).toBe('weekly');
    expect(enviado.recurrence_end_at).toBeNull();
    expect(enviado.recurrence_count).toBeNull();
  });

  it('envia so a data quando o termino e "em uma data"', async () => {
    const wrapper = montar();
    await frequencySelect(wrapper).setValue('weekly');
    await radios(wrapper)[1].setValue(); // on_date
    await wrapper.find('input[type="date"]').setValue('2026-12-31');

    await salvar(wrapper).trigger('click');

    const enviado = wrapper.emitted('submit')[0][0];
    expect(enviado.recurrence_end_at).toBe('2026-12-31');
    expect(enviado.recurrence_count).toBeNull();
  });

  it('envia so a quantidade quando o termino e "depois de N ocorrencias"', async () => {
    const wrapper = montar();
    await frequencySelect(wrapper).setValue('weekly');
    await radios(wrapper)[2].setValue(); // after_count
    const countInput = wrapper.findAll('input[type="number"]')[1];
    await countInput.setValue(10);

    await salvar(wrapper).trigger('click');

    const enviado = wrapper.emitted('submit')[0][0];
    expect(enviado.recurrence_end_at).toBeNull();
    expect(enviado.recurrence_count).toBe(10);
  });

  it('zera intervalo e termino ao voltar para "nao se repete"', async () => {
    const wrapper = montar({
      event: {
        ...EVENTO_BASE,
        recurrence_frequency: 'weekly',
        recurrence_interval: 2,
        recurrence_count: 5,
      },
    });

    await frequencySelect(wrapper).setValue('single');
    await salvar(wrapper).trigger('click');

    const enviado = wrapper.emitted('submit')[0][0];
    expect(enviado.recurrence_interval).toBeNull();
    expect(enviado.recurrence_end_at).toBeNull();
    expect(enviado.recurrence_count).toBeNull();
  });
});
