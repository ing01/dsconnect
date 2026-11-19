import { mount, flushPromises } from '@vue/test-utils';
import AgentNichesPage from '../AgentNichesPage.vue';
import AgentNichesAPI from 'dashboard/api/agentNiches';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/agentNiches', () => ({
  default: { list: vi.fn(), save: vi.fn() },
}));

const DATA = {
  agents: [
    {
      id: 1,
      name: 'Ingrid',
      email: 'i@x.com',
      niche_ids: [1],
      sub_niche_ids: [],
    },
    {
      id: 2,
      name: 'João Vitor',
      email: 'j@x.com',
      niche_ids: [2],
      sub_niche_ids: [10],
    },
  ],
  niches: [
    { id: 1, name: 'Variedades' },
    { id: 2, name: 'Indústria de alimentos' },
  ],
  sub_niches: [
    { id: 10, name: 'Padaria / panificadora' },
    { id: 11, name: 'Informática' },
  ],
};

// O layout das configuracoes depende de rotas e do menu: aqui so' importa o conteudo.
const SettingsLayoutStub = {
  template: '<div><slot name="header" /><slot name="body" /></div>',
};

const ButtonStub = {
  props: ['label', 'disabled'],
  template: '<button :disabled="disabled" v-bind="$attrs">{{ label }}</button>',
};

const mountPage = async () => {
  AgentNichesAPI.list.mockResolvedValue({ data: DATA });
  const wrapper = mount(AgentNichesPage, {
    global: {
      stubs: {
        SettingsLayout: SettingsLayoutStub,
        BaseSettingsHeader: true,
        Button: ButtonStub,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('AgentNichesPage', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows each agent with the niches and sub-niches they cover', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('[data-testid="agent-1"]').text()).toContain(
      'Variedades'
    );
    const joao = wrapper.find('[data-testid="agent-2"]').text();
    expect(joao).toContain('Indústria de alimentos');
    expect(joao).toContain('Padaria / panificadora');
  });

  it('finds agents by niche, in any position of the structure', async () => {
    const wrapper = await mountPage();

    await wrapper
      .find('[data-testid="agent-niches-search"]')
      .setValue('padaria');

    expect(wrapper.find('[data-testid="agent-1"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="agent-2"]').exists()).toBe(true);
  });

  it('says so when nothing matches the search', async () => {
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="agent-niches-search"]').setValue('zzz');

    expect(wrapper.find('[data-testid="agent-niches-empty"]').exists()).toBe(
      true
    );
  });

  it('opens the editor with what the agent has today, and keeps Save off until something changes', async () => {
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="agent-edit-2"]').trigger('click');

    expect(wrapper.find('[data-testid="niche-2"]').element.checked).toBe(true);
    expect(wrapper.find('[data-testid="niche-1"]').element.checked).toBe(false);
    expect(
      wrapper.find('[data-testid="agent-save"]').attributes('disabled')
    ).toBeDefined();
  });

  it('saves the new lists and shows them in the card', async () => {
    AgentNichesAPI.save.mockResolvedValue({
      data: {
        id: 2,
        name: 'João Vitor',
        email: 'j@x.com',
        niche_ids: [1, 2],
        sub_niche_ids: [10, 11],
      },
    });
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="agent-edit-2"]').trigger('click');
    await wrapper.find('[data-testid="niche-1"]').setValue(true);
    await wrapper.find('[data-testid="sub-niche-11"]').setValue(true);
    await wrapper.find('[data-testid="agent-save"]').trigger('click');
    await flushPromises();

    expect(AgentNichesAPI.save).toHaveBeenCalledWith(2, {
      nicheIds: [2, 1],
      subNicheIds: [10, 11],
    });
    expect(wrapper.find('[data-testid="agent-editor-2"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="agent-2"]').text()).toContain(
      'Informática'
    );
  });

  it('keeps the editor open and warns when saving fails', async () => {
    AgentNichesAPI.save.mockRejectedValue({
      response: { data: { message: 'Erro X' } },
    });
    const wrapper = await mountPage();

    await wrapper.find('[data-testid="agent-edit-1"]').trigger('click');
    await wrapper.find('[data-testid="niche-2"]').setValue(true);
    await wrapper.find('[data-testid="agent-save"]').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('Erro X');
    expect(wrapper.find('[data-testid="agent-editor-1"]').exists()).toBe(true);
  });
});
