import { mount, flushPromises } from '@vue/test-utils';
import MonthlySatisfactionSurveysPage from '../MonthlySatisfactionSurveysPage.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

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

// Media por pergunta sempre com as dez chaves (o servidor manda `null` pra
// quem ainda nao tem resposta) - a primeira chave fica mais baixa de
// proposito, para testar o card "pergunta com menor media".
const buildMeta = (overrides = {}) => ({
  count: 1,
  average_rating: 3.5,
  average_by_question: QUESTION_KEYS.reduce((acc, chave, indice) => {
    acc[chave] = indice === 0 ? 2 : 4;
    return acc;
  }, {}),
  ...overrides,
});

const buildItem = (id, overrides = {}) => ({
  id,
  reference_month: '2026-10-01',
  comment: null,
  created_at: 1760000000,
  company_id: 1,
  company_name: 'Empresa A',
  contact_id: 1,
  contact_name: 'Fulano de Tal',
  average_rating: 4,
  answers: QUESTION_KEYS.map(chave => ({ question_key: chave, rating: 4 })),
  ...overrides,
});

const get = vi.fn(() =>
  Promise.resolve({
    data: { payload: [buildItem(1)], meta: buildMeta() },
  })
);

vi.mock('dashboard/api/monthlySatisfactionSurveys', () => ({
  default: { get: (...args) => get(...args) },
}));

const CompanySelectStub = {
  props: {
    modelValue: { type: [Number, String], default: null },
    initialName: { type: String, default: '' },
  },
  emits: ['update:modelValue', 'select'],
  template: `<button
    class="company-select"
    @click="$emit('update:modelValue', 2); $emit('select', { id: 2, name: 'Empresa B' })"
  />`,
};

const ReportCardStub = {
  props: { header: { type: String, default: '' }, isLoading: Boolean },
  template: `<div class="report-card">
    <span class="card-header">{{ header }}</span>
    <div v-if="isLoading" class="card-loading" />
    <div v-else class="card-body"><slot /></div>
  </div>`,
};

const BarChartStub = {
  props: ['data', 'ariaLabel', 'height'],
  template: `<div class="bar-chart" />`,
};

const montar = () =>
  mount(MonthlySatisfactionSurveysPage, {
    global: {
      stubs: {
        ReportHeader: true,
        ReportCard: ReportCardStub,
        TicketCompanySelect: CompanySelectStub,
        BarChart: BarChartStub,
      },
    },
  });

const rows = wrapper => wrapper.findAll('tbody > tr');

beforeEach(() => {
  get.mockClear();
});

describe('MonthlySatisfactionSurveysPage', () => {
  it('loads and shows the KPI cards', async () => {
    const wrapper = montar();
    await flushPromises();

    const cards = wrapper.findAll('.report-card');
    expect(cards[0].text()).toContain('3.5');
    expect(cards[1].text()).toContain('1');
  });

  // O ponto que o pedido deixa explicito para o futuro: identificar o ponto
  // mais fraco da pesquisa de cara, sem precisar ler o grafico todo.
  it('highlights the lowest-rated question', async () => {
    const wrapper = montar();
    await flushPromises();

    const cards = wrapper.findAll('.report-card');
    expect(cards[2].text()).toContain('2');
  });

  it('lists one table row per response', async () => {
    get.mockResolvedValueOnce({
      data: {
        payload: [buildItem(1), buildItem(2, { company_name: 'Empresa B' })],
        meta: buildMeta({ count: 2 }),
      },
    });
    const wrapper = montar();
    await flushPromises();

    expect(rows(wrapper)).toHaveLength(2);
  });

  it('expands a row to show the ten answers plus the comment', async () => {
    get.mockResolvedValueOnce({
      data: {
        payload: [buildItem(1, { comment: 'Podiam agilizar o suporte.' })],
        meta: buildMeta(),
      },
    });
    const wrapper = montar();
    await flushPromises();

    expect(rows(wrapper)).toHaveLength(1);
    expect(wrapper.text()).not.toContain(
      'MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.DETAILS_TITLE'
    );

    await rows(wrapper)[0].trigger('click');

    expect(rows(wrapper)).toHaveLength(2);
    expect(wrapper.text()).toContain(
      'MONTHLY_SATISFACTION_SURVEY_REPORT.TABLE.DETAILS_TITLE'
    );
    expect(wrapper.text()).toContain('Podiam agilizar o suporte.');

    await rows(wrapper)[0].trigger('click');

    expect(rows(wrapper)).toHaveLength(1);
  });

  it('shows the empty state when there are no responses', async () => {
    get.mockResolvedValueOnce({
      data: {
        payload: [],
        meta: buildMeta({
          count: 0,
          average_rating: null,
          average_by_question: QUESTION_KEYS.reduce((acc, chave) => {
            acc[chave] = null;
            return acc;
          }, {}),
        }),
      },
    });
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'MONTHLY_SATISFACTION_SURVEY_REPORT.EMPTY'
    );
  });

  // Filtrar "por empresa", como pedido - o id escolhido no seletor vai
  // direto pro parametro que o backend ja aceita.
  it('refetches filtered by company when one is picked', async () => {
    const wrapper = montar();
    await flushPromises();
    get.mockClear();

    await wrapper.find('.company-select').trigger('click');
    await flushPromises();

    expect(get).toHaveBeenCalledWith(
      expect.objectContaining({ company_id: 2 })
    );
  });

  it('refetches filtered by month, as the first day of that month', async () => {
    const wrapper = montar();
    await flushPromises();
    get.mockClear();

    await wrapper.find('input[type="month"]').setValue('2026-09');
    await flushPromises();

    expect(get).toHaveBeenCalledWith(
      expect.objectContaining({ reference_month: '2026-09-01' })
    );
  });

  it('drops the month filter once cleared', async () => {
    const wrapper = montar();
    await flushPromises();
    await wrapper.find('input[type="month"]').setValue('2026-09');
    await flushPromises();
    get.mockClear();

    await wrapper.find('.clear-month').trigger('click');
    await flushPromises();

    expect(get).toHaveBeenCalledWith(
      expect.not.objectContaining({ reference_month: expect.anything() })
    );
  });
});
