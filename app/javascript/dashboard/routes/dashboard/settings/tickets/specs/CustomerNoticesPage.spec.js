import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import CustomerNoticesPage from '../CustomerNoticesPage.vue';
import NoticesAPI from 'dashboard/api/ticketCustomerNoticeRules';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => {
  holder.dispatch = vi.fn(() => Promise.resolve());
  return {
    useStore: () => ({
      dispatch: holder.dispatch,
      getters: {
        'ticketColumns/getColumns': teamId =>
          ({
            1: [
              { id: 11, name: 'Melhoria aprovada' },
              { id: 12, name: 'Finalizado' },
            ],
            2: [{ id: 21, name: 'Triagem' }],
          })[teamId] || [],
      },
    }),
    useStoreGetters: () => ({
      'teams/getTeams': ref([
        { id: 1, name: 'desenvolvimento' },
        { id: 2, name: 'suporte' },
      ]),
    }),
  };
});
vi.mock('dashboard/api/ticketCustomerNoticeRules', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(() => Promise.resolve({ data: {} })),
    update: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({})),
  },
}));

const RULES = [
  {
    id: 5,
    kind: 'stage',
    name: 'Aprovada',
    ticket_column_id: 11,
    team_id: null,
    from_team_id: null,
    body: 'Seu ticket #{{numero}} foi aprovado.',
    notify_customer: true,
    active: true,
  },
  {
    id: 6,
    kind: 'team',
    name: 'Foi para o suporte',
    ticket_column_id: null,
    team_id: 2,
    from_team_id: 1,
    body: 'Agora está com o suporte.',
    notify_customer: false,
    active: false,
  },
];

const mountPage = async () => {
  NoticesAPI.get.mockResolvedValue({ data: { payload: RULES } });
  const wrapper = mount(CustomerNoticesPage, {
    global: {
      directives: { tooltip: () => {} },
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: {
          template: '<div><slot name="actions" /></div>',
        },
        Button: {
          props: ['label', 'disabled'],
          template:
            '<button :disabled="disabled" v-bind="$attrs">{{ label }}</button>',
        },
        Icon: true,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('CustomerNoticesPage', () => {
  beforeEach(() => vi.clearAllMocks());

  it('lists each message saying when it fires', async () => {
    const wrapper = await mountPage();

    const stage = wrapper.find('[data-testid="notice-5"]').text();
    expect(stage).toContain('Aprovada');
    expect(stage).toContain('Melhoria aprovada');
    expect(stage).toContain('Desenvolvimento');

    const team = wrapper.find('[data-testid="notice-6"]').text();
    expect(team).toContain('WHEN_TEAM_FROM');
    expect(team).toContain('Suporte');
    expect(team).toContain('TICKET.SETTINGS.NOTICES.INACTIVE');
    expect(team).toContain('TICKET.SETTINGS.NOTICES.REGISTER_ONLY');
  });

  it('creates a stage message once the Mesa, the Estagio and the text are chosen', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-testid="notice-add"]').trigger('click');

    const submit = () => wrapper.find('[data-testid="notice-submit"]');
    expect(submit().attributes('disabled')).toBeDefined();

    await wrapper.find('[data-testid="notice-name"]').setValue('Finalizado');
    await wrapper.find('[data-testid="notice-team"]').setValue('1');
    await wrapper.find('[data-testid="notice-stage"]').setValue('12');
    await wrapper
      .find('[data-testid="notice-body"]')
      .setValue('Seu ticket #{{numero}} foi finalizado.');
    expect(submit().attributes('disabled')).toBeUndefined();

    await wrapper.find('[data-testid="notice-form"]').trigger('submit');
    await flushPromises();

    expect(NoticesAPI.create).toHaveBeenCalledWith({
      ticket_customer_notice_rule: {
        kind: 'stage',
        name: 'Finalizado',
        body: 'Seu ticket #{{numero}} foi finalizado.',
        notify_customer: true,
        active: true,
        ticket_column_id: 12,
      },
    });
  });

  it('creates a Mesa change message, with or without an origin Mesa', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-testid="notice-add"]').trigger('click');
    await wrapper.find('[data-testid="notice-kind-team"]').setValue(true);

    await wrapper
      .find('[data-testid="notice-name"]')
      .setValue('Para o suporte');
    await wrapper.find('[data-testid="notice-team"]').setValue('2');
    await wrapper
      .find('[data-testid="notice-body"]')
      .setValue('Com o suporte.');
    await wrapper.find('[data-testid="notice-form"]').trigger('submit');
    await flushPromises();

    expect(NoticesAPI.create).toHaveBeenCalledWith({
      ticket_customer_notice_rule: expect.objectContaining({
        kind: 'team',
        team_id: 2,
        from_team_id: null,
      }),
    });
  });

  it('inserts a variable into the text', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-testid="notice-add"]').trigger('click');
    await wrapper.find('[data-testid="notice-body"]').setValue('Olá ');

    await wrapper.find('[data-testid="notice-var-numero"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="notice-body"]').element.value).toContain(
      '{{numero}}'
    );
  });

  it('opens a message for editing with its Mesa and Estagio filled in', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-testid="notice-edit-5"]').trigger('click');

    expect(wrapper.find('[data-testid="notice-name"]').element.value).toBe(
      'Aprovada'
    );
    expect(wrapper.find('[data-testid="notice-team"]').element.value).toBe('1');
    expect(wrapper.find('[data-testid="notice-stage"]').element.value).toBe(
      '11'
    );
  });

  it('turns a message off and deletes it after confirming', async () => {
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="notice-toggle-5"]').trigger('click');
    await flushPromises();
    expect(NoticesAPI.update).toHaveBeenCalledWith(5, {
      ticket_customer_notice_rule: { active: false },
    });

    await wrapper.find('[data-testid="notice-delete-6"]').trigger('click');
    expect(NoticesAPI.delete).not.toHaveBeenCalled();
    await wrapper
      .find('[data-testid="notice-delete-confirm"]')
      .trigger('click');
    await flushPromises();

    expect(NoticesAPI.delete).toHaveBeenCalledWith(6);
    expect(wrapper.find('[data-testid="notice-6"]').exists()).toBe(false);
  });
});
