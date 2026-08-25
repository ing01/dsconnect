import { mount, flushPromises } from '@vue/test-utils';
import TicketCreateForm from '../TicketCreateForm.vue';

const { dispatch, getters, holder } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  getters: {},
  holder: {},
}));

// `useMapGetter` has to hand back a genuine ref: the template only unwraps real
// refs, so a plain { value: [] } would render as an empty list.
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.teams = ref([]);
  return {
    useStore: () => ({ dispatch, getters }),
    useMapGetter: () => holder.teams,
  };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const COLUMNS = {
  1: [
    { id: 10, name: 'A fazer' },
    { id: 11, name: 'Em andamento' },
  ],
  2: [{ id: 20, name: 'Triagem' }],
};
const CATEGORIES = {
  1: [
    { id: 100, name: 'Erro' },
    { id: 101, name: 'Duvida' },
  ],
  2: [{ id: 200, name: 'Proposta' }],
};
const MEMBERS = {
  1: [{ id: 50, name: 'Ana' }],
  2: [{ id: 60, name: 'Bruno' }],
};

const stubSelect = name => ({
  name,
  props: { modelValue: [Number, String], companyId: [Number, String] },
  emits: ['update:modelValue'],
  template: '<div />',
});

const mountForm = async (context = {}) => {
  const wrapper = mount(TicketCreateForm, {
    props: { context },
    global: {
      stubs: {
        TicketCompanySelect: stubSelect('TicketCompanySelect'),
        TicketContactSelect: stubSelect('TicketContactSelect'),
        TicketPicker: stubSelect('TicketPicker'),
        TicketFollowersSelect: stubSelect('TicketFollowersSelect'),
        TicketFileInput: true,
        TicketRecentCompanyTickets: true,
        TicketKnowledgeAccordion: true,
        FullEditor: {
          name: 'FullEditor',
          props: { modelValue: String },
          emits: ['update:modelValue'],
          template: '<div />',
        },
        Button: {
          props: ['label'],
          emits: ['click'],
          template: '<button @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

// [0] Mesa, [1] Estagio, [2] Prioridade, [3] Responsavel, [4] Categoria
const selects = wrapper => wrapper.findAll('select');
const optionsOf = (wrapper, index) =>
  selects(wrapper)[index]
    .findAll('option')
    .map(option => option.text());

const setCompany = async (wrapper, id) => {
  await wrapper
    .findComponent({ name: 'TicketCompanySelect' })
    .vm.$emit('update:modelValue', id);
  await flushPromises();
};

describe('TicketCreateForm', () => {
  beforeEach(() => {
    dispatch.mockClear();
    holder.teams.value = [
      { id: 1, name: 'Suporte' },
      { id: 2, name: 'Comercial' },
    ];
    getters['ticketColumns/getColumns'] = id => COLUMNS[id] || [];
    getters['ticketColumns/getCategories'] = id => CATEGORIES[id] || [];
    getters['teamMembers/getTeamMembers'] = id => MEMBERS[id] || [];
  });

  describe('the context the caller already knows', () => {
    // The Kanban knows the Mesa and the Estagio of the column that was clicked.
    it('pre-fills the Mesa and the Estagio', async () => {
      const wrapper = await mountForm({ teamId: 1, ticketColumnId: 11 });

      expect(selects(wrapper)[0].element.value).toBe('1');
      expect(selects(wrapper)[1].element.value).toBe('11');
    });

    it('loads that Mesa lists without being asked again', async () => {
      await mountForm({ teamId: 1 });

      expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchColumns', 1);
      expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchCategories', 1);
      expect(dispatch).toHaveBeenCalledWith('teamMembers/get', { teamId: 1 });
    });

    // A chat knows the Empresa and the Solicitante.
    it('pre-fills the Solicitante scoped to the Empresa', async () => {
      const wrapper = await mountForm({ companyId: 7, contactId: 3 });

      expect(
        wrapper.findComponent({ name: 'TicketContactSelect' }).props('companyId')
      ).toBe(7);
    });

    it('locks the parent when the flow started from a parent ticket', async () => {
      const wrapper = await mountForm({ parentId: 9 });

      expect(wrapper.findComponent({ name: 'TicketPicker' }).attributes()).toHaveProperty(
        'disabled'
      );
    });
  });

  describe('the Mesa drives its dependent fields', () => {
    it('lists only that Mesa Estagios and Categorias', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      expect(optionsOf(wrapper, 1)).toEqual(['A fazer', 'Em andamento']);
      expect(optionsOf(wrapper, 4).slice(1)).toEqual(['Erro', 'Duvida']);
    });

    it('lists only that Mesa members as Responsavel', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      expect(optionsOf(wrapper, 3).slice(1)).toEqual(['Ana']);
    });

    it('reloads everything when the Mesa changes', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      dispatch.mockClear();

      await selects(wrapper)[0].setValue('2');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchCategories', 2);
      expect(optionsOf(wrapper, 4).slice(1)).toEqual(['Proposta']);
      expect(optionsOf(wrapper, 3).slice(1)).toEqual(['Bruno']);
    });

    // Keeping them would submit a Categoria and a Responsavel from the previous
    // Mesa, which the backend refuses anyway.
    it('drops the Categoria and the Responsavel that belonged to the old Mesa', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      await selects(wrapper)[4].setValue('100');
      await selects(wrapper)[3].setValue('50');

      await selects(wrapper)[0].setValue('2');
      await flushPromises();

      // Index 0 is the disabled placeholder, which is where a cleared select
      // lands - its rendered value is the placeholder text, not ''.
      expect(selects(wrapper)[4].element.selectedIndex).toBe(0);
      expect(selects(wrapper)[3].element.selectedIndex).toBe(0);
    });

    it('defaults to the first Estagio of the new Mesa', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      await selects(wrapper)[0].setValue('2');
      await flushPromises();

      expect(selects(wrapper)[1].element.value).toBe('20');
    });
  });

  // The Solicitante belongs to the Empresa.
  it('clears the Solicitante when the Empresa changes', async () => {
    const wrapper = await mountForm({ companyId: 7, contactId: 3 });

    await setCompany(wrapper, 8);
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeUndefined();
  });

  describe('validation', () => {
    const fill = async wrapper => {
      await setCompany(wrapper, 7);
      await wrapper
        .findComponent({ name: 'TicketContactSelect' })
        .vm.$emit('update:modelValue', 3);
      await selects(wrapper)[4].setValue('100');
      await wrapper.find('input[type="text"]').setValue('Erro na NF');
      await wrapper
        .findComponent({ name: 'FullEditor' })
        .vm.$emit('update:modelValue', 'detalhes');
      await flushPromises();
    };

    it('refuses to submit while a required field is empty', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('submits everything the form collected', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      await fill(wrapper);

      await wrapper.find('form').trigger('submit');

      const payload = wrapper.emitted('submit')[0][0];
      expect(payload.ticket).toMatchObject({
        title: 'Erro na NF',
        description: 'detalhes',
        company_id: 7,
        contact_id: 3,
        team_id: 1,
        ticket_column_id: 10,
        ticket_category_id: 100,
        priority: 'medium',
      });
    });

    it('sends no assignee when none was chosen', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      await fill(wrapper);

      await wrapper.find('form').trigger('submit');

      expect(wrapper.emitted('submit')[0][0].ticket.assignee_id).toBeNull();
    });
  });

  describe('"criar e abrir outro"', () => {
    it('is offered only when the caller allows it', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      expect(wrapper.text()).not.toContain('SUBMIT_AND_NEW');
    });

    it('asks for the form to be reset once the ticket is created', async () => {
      const wrapper = mount(TicketCreateForm, {
        props: { context: { teamId: 1 }, allowCreateAnother: true },
        global: {
          stubs: {
            TicketCompanySelect: stubSelect('TicketCompanySelect'),
            TicketContactSelect: stubSelect('TicketContactSelect'),
            TicketPicker: stubSelect('TicketPicker'),
            TicketFollowersSelect: stubSelect('TicketFollowersSelect'),
            TicketFileInput: true,
            TicketRecentCompanyTickets: true,
            TicketKnowledgeAccordion: true,
            FullEditor: {
              name: 'FullEditor',
              props: { modelValue: String },
              emits: ['update:modelValue'],
              template: '<div />',
            },
            Button: {
              props: ['label'],
              emits: ['click'],
              template: '<button @click="$emit(\'click\')">{{ label }}</button>',
            },
          },
        },
      });
      await flushPromises();

      await setCompany(wrapper, 7);
      await wrapper
        .findComponent({ name: 'TicketContactSelect' })
        .vm.$emit('update:modelValue', 3);
      await selects(wrapper)[4].setValue('100');
      await wrapper.find('input[type="text"]').setValue('Erro na NF');
      await wrapper
        .findComponent({ name: 'FullEditor' })
        .vm.$emit('update:modelValue', 'detalhes');
      await flushPromises();

      const another = wrapper
        .findAll('button')
        .find(button => button.text().includes('SUBMIT_AND_NEW'));
      await another.trigger('click');

      const payload = wrapper.emitted('submit')[0][0];
      expect(payload.createAnother).toBe(true);
      expect(typeof payload.onCreated).toBe('function');

      // Clears what describes this ticket and keeps the context the agent would
      // otherwise retype.
      payload.onCreated();
      await flushPromises();
      expect(wrapper.find('input[type="text"]').element.value).toBe('');
      expect(selects(wrapper)[4].element.selectedIndex).toBe(0);
      expect(selects(wrapper)[0].element.value).toBe('1');
    });
  });
});
