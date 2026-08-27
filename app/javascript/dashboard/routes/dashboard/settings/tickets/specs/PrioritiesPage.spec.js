import { mount, flushPromises } from '@vue/test-utils';
import PrioritiesPage from '../PrioritiesPage.vue';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.dispatch = vi.fn(() => Promise.resolve());
  holder.teams = ref([{ id: 7, name: 'suporte' }]);
  holder.policies = ref([]);
  holder.workingHours = ref({
    working_hours_enabled: false,
    working_hours: [],
  });

  return {
    useStore: () => ({ dispatch: holder.dispatch }),
    useStoreGetters: () => ({
      'teams/getTeams': holder.teams,
      'ticketColumns/getSlaPolicies': ref(() => holder.policies.value),
      'ticketColumns/getWorkingHours': ref(() => holder.workingHours.value),
    }),
  };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountPage = async () => {
  const wrapper = mount(PrioritiesPage, {
    global: {
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: true,
        TeamWorkingHours: true,
        Button: { template: '<button />' },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

// A tabela do BaseTable só desenha quando recebe `items` e as linhas vão no
// slot `row`. Passar apenas `headers` produz uma tela em branco silenciosa -
// foi exatamente o que aconteceu, e é o que estes testes travam.
describe('PrioritiesPage', () => {
  it('renders one row per real ticket priority', async () => {
    const wrapper = await mountPage();

    expect(wrapper.findAll('tbody tr')).toHaveLength(4);
  });

  it('names each priority from the ticket namespace', async () => {
    const wrapper = await mountPage();
    const labels = wrapper
      .findAll('tbody tr td:first-child')
      .map(c => c.text());

    expect(labels).toEqual([
      'TICKET.FORM.PRIORITY.LOW',
      'TICKET.FORM.PRIORITY.MEDIUM',
      'TICKET.FORM.PRIORITY.HIGH',
      'TICKET.FORM.PRIORITY.URGENT',
    ]);
  });

  it('offers a response and a resolution field on every row', async () => {
    const wrapper = await mountPage();

    expect(wrapper.findAll('tbody input[type="text"]')).toHaveLength(8);
  });

  // O cabeçalho do BaseTable só aparece junto com as linhas, então a ausência
  // dele é o mesmo sintoma da tabela vazia.
  it('shows the three column headers', async () => {
    const wrapper = await mountPage();

    expect(wrapper.findAll('thead th')).toHaveLength(3);
  });

  it('fills the fields from the saved matrix', async () => {
    holder.policies.value = [
      {
        id: 1,
        priority: 'high',
        response_threshold: 2400,
        resolution_threshold: 36000,
      },
    ];

    const wrapper = await mountPage();
    const highRow = wrapper.findAll('tbody tr')[2];
    const values = highRow.findAll('input').map(i => i.element.value);

    expect(values).toEqual(['00:40', '10:00']);
    holder.policies.value = [];
  });
});
