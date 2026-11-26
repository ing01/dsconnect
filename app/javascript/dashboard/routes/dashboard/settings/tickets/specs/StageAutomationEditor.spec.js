import { mount } from '@vue/test-utils';
import StageAutomationEditor from '../StageAutomationEditor.vue';

const dispatch = vi.fn(() => Promise.resolve());
const getters = {
  'ticketColumns/getSprints': () => [{ id: 7, name: 'Sprint 12' }],
  'ticketColumns/getCategories': () => [{ id: 3, name: 'Erro' }],
  'ticketComplexities/getComplexitiesForTeam': () => [],
};

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: (...args) => dispatch(...args), getters }),
}));

const montar = value =>
  mount(StageAutomationEditor, {
    props: {
      teamId: 2,
      modelValue: [{ type: 'set_field', value }],
    },
    global: {
      stubs: { NextButton: true },
      directives: { tooltip: {} },
    },
  });

const options = (wrapper, id) =>
  wrapper
    .find(`[data-testid="${id}"]`)
    .findAll('option')
    .map(option => option.text());
const lastValue = wrapper =>
  wrapper.emitted('update:modelValue').at(-1)[0][0].value;

describe('StageAutomationEditor - alterar um campo', () => {
  it('oferece o Backlog e os Sprints da Mesa', () => {
    const wrapper = montar({ field: 'sprint', value: '' });

    expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchSprints', 2);
    expect(options(wrapper, 'automation-value')).toEqual([
      'TICKET.SETTINGS.FORM.AUTOMATION.BACKLOG',
      'Sprint 12',
    ]);
  });

  it('datas so podem ser limpas', () => {
    const wrapper = montar({ field: 'due_date', value: '' });

    expect(options(wrapper, 'automation-value')).toEqual([
      'TICKET.SETTINGS.FORM.AUTOMATION.CLEAR_VALUE',
    ]);
  });

  it('trocar o campo zera o valor escolhido', async () => {
    const wrapper = montar({ field: 'sprint', value: '7' });

    await wrapper.find('[data-testid="automation-field"]').setValue('category');

    expect(lastValue(wrapper)).toEqual({ field: 'category', value: '' });
  });

  it('guarda o valor escolhido junto do campo', async () => {
    const wrapper = montar({ field: 'category', value: '' });

    await wrapper.find('[data-testid="automation-value"]').setValue('3');

    expect(lastValue(wrapper)).toEqual({ field: 'category', value: '3' });
  });
});
