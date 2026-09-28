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

// Por padrao nenhuma Mesa usa niveis; os testes que precisam ligam na hora.
const TEAMS_BY_ID = {};

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

// Espelha o TicketSelect, o seletor padrao do modulo: expoe as opcoes, o valor
// atual e devolve o que for escolhido.
const ticketSelectStub = {
  props: {
    modelValue: { type: [Number, String, Array], default: null },
    options: { type: Array, default: () => [] },
    clearable: { type: Boolean, default: false },
    clearLabel: { type: String, default: '' },
    disabled: { type: Boolean, default: false },
  },
  emits: ['update:modelValue'],
  template: `<div
    class="ticket-select"
    :data-model="modelValue === null ? '' : String(modelValue)"
    :data-disabled="String(disabled)"
  >
    <button
      v-if="clearable"
      data-value=""
      @click="$emit('update:modelValue', null)"
    >{{ clearLabel }}</button>
    <button
      v-for="option in options"
      :key="String(option.value)"
      :data-value="String(option.value)"
      @click="$emit('update:modelValue', option.value)"
    >{{ option.label }}</button>
  </div>`,
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
        TicketSelect: ticketSelectStub,
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
const selects = wrapper => wrapper.findAll('.ticket-select');

// O valor atual de um campo, como o stub o expoe.
const valueOf = (wrapper, index) =>
  selects(wrapper)[index].attributes('data-model');

// Escolher uma opcao pelo valor.
const choose = async (wrapper, index, value) =>
  selects(wrapper)[index].find(`[data-value="${value}"]`).trigger('click');

// As opcoes visiveis, sem a entrada que esvazia.
const optionsOf = (wrapper, index) =>
  selects(wrapper)
    [index].findAll('button')
    .filter(button => button.attributes('data-value') !== '')
    .map(button => button.text());

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
    Object.keys(TEAMS_BY_ID).forEach(k => delete TEAMS_BY_ID[k]);
    getters['ticketColumns/getColumns'] = id => COLUMNS[id] || [];
    getters['ticketColumns/getCategories'] = id => CATEGORIES[id] || [];
    getters['teamMembers/getTeamMembers'] = id => MEMBERS[id] || [];
    // A Mesa diz quantos niveis de responsavel usa. Sem niveis configurados o
    // formulario mostra um campo de responsavel so, como sempre mostrou.
    getters['teams/getTeam'] = id => TEAMS_BY_ID[id] || null;
  });

  describe('the context the caller already knows', () => {
    // The Kanban knows the Mesa and the Estagio of the column that was clicked.
    it('pre-fills the Mesa and the Estagio', async () => {
      const wrapper = await mountForm({ teamId: 1, ticketColumnId: 11 });

      expect(valueOf(wrapper, 0)).toBe('1');
      expect(valueOf(wrapper, 1)).toBe('11');
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
        wrapper
          .findComponent({ name: 'TicketContactSelect' })
          .props('companyId')
      ).toBe(7);
    });

    it('locks the parent when the flow started from a parent ticket', async () => {
      const wrapper = await mountForm({ parentId: 9 });

      expect(
        wrapper.findComponent({ name: 'TicketPicker' }).attributes()
      ).toHaveProperty('disabled');
    });
  });

  describe('the Mesa drives its dependent fields', () => {
    it('lists only that Mesa Estagios and Categorias', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      expect(optionsOf(wrapper, 1)).toEqual(['A fazer', 'Em andamento']);
      expect(optionsOf(wrapper, 4)).toEqual(['Erro', 'Duvida']);
    });

    it('lists only that Mesa members as Responsavel', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      expect(optionsOf(wrapper, 3)).toEqual(['Ana']);
    });

    it('reloads everything when the Mesa changes', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      dispatch.mockClear();

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchCategories', 2);
      expect(optionsOf(wrapper, 4)).toEqual(['Proposta']);
      expect(optionsOf(wrapper, 3)).toEqual(['Bruno']);
    });

    // Keeping them would submit a Categoria and a Responsavel from the previous
    // Mesa, which the backend refuses anyway.
    it('drops the Categoria and the Responsavel that belonged to the old Mesa', async () => {
      const wrapper = await mountForm({ teamId: 1 });
      await choose(wrapper, 4, '100');
      await choose(wrapper, 3, '50');

      await choose(wrapper, 0, '2');
      await flushPromises();

      // Index 0 is the disabled placeholder, which is where a cleared select
      // lands - its rendered value is the placeholder text, not ''.
      expect(valueOf(wrapper, 4)).toBe('');
      expect(valueOf(wrapper, 3)).toBe('');
    });

    it('defaults to the first Estagio of the new Mesa', async () => {
      const wrapper = await mountForm({ teamId: 1 });

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(valueOf(wrapper, 1)).toBe('20');
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
      await choose(wrapper, 4, '100');
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

    // Uma Mesa com niveis pode nao ter ninguem no Nivel 1 - e isso travava a
    // abertura inteira, porque o unico campo de responsavel gravava sempre no
    // Nivel 1 e o servidor recusava qualquer agente de outro nivel.
    describe('Mesa com niveis de responsavel', () => {
      beforeEach(() => {
        TEAMS_BY_ID[1] = { id: 1, assignee_levels: [1, 2] };
        MEMBERS[1] = [
          { id: 50, name: 'Ana', levels: [2] },
          { id: 51, name: 'Carla', levels: [1] },
        ];
      });

      // Achar o campo pelo agente que ele oferece: os dois tem o mesmo rotulo
      // aqui, porque o `t` do teste devolve a chave sem interpolar o nivel.
      const campoQueOferece = (wrapper, id) =>
        selects(wrapper).find(s => s.find(`[data-value="${id}"]`).exists());

      const opcoesDe = campo =>
        campo.findAll('[data-value]').map(o => o.attributes('data-value'));

      it('offers one field per level, with only that level agents', async () => {
        const wrapper = await mountForm({ teamId: 1 });

        // Carla e do Nivel 1, Ana do Nivel 2 - e cada campo so oferece o seu.
        expect(opcoesDe(campoQueOferece(wrapper, 51))).not.toContain('50');
        expect(opcoesDe(campoQueOferece(wrapper, 50))).not.toContain('51');
      });

      // O pedido: abrir indicando SO o Nivel 2.
      it('opens with a level 2 assignee alone', async () => {
        const wrapper = await mountForm({ teamId: 1 });

        // Preenchido pelo que cada campo OFERECE, e nao por posicao: com dois
        // campos de responsavel os indices deslocam.
        await setCompany(wrapper, 7);
        await wrapper
          .findComponent({ name: 'TicketContactSelect' })
          .vm.$emit('update:modelValue', 3);
        await campoQueOferece(wrapper, 100)
          .find('[data-value="100"]')
          .trigger('click');
        await wrapper.find('input[type="text"]').setValue('Erro na NF');
        await wrapper
          .findComponent({ name: 'FullEditor' })
          .vm.$emit('update:modelValue', 'detalhes');
        await flushPromises();
        await campoQueOferece(wrapper, 50)
          .find('[data-value="50"]')
          .trigger('click');

        await wrapper.find('form').trigger('submit');

        const enviado = wrapper.emitted('submit')[0][0].ticket;
        expect(enviado.assignee_2_id).toBe(50);
        expect(enviado.assignee_id).toBeNull();
      });
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
            TicketSelect: ticketSelectStub,
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
              template:
                '<button @click="$emit(\'click\')">{{ label }}</button>',
            },
          },
        },
      });
      await flushPromises();

      await setCompany(wrapper, 7);
      await wrapper
        .findComponent({ name: 'TicketContactSelect' })
        .vm.$emit('update:modelValue', 3);
      await choose(wrapper, 4, '100');
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
      expect(valueOf(wrapper, 4)).toBe('');
      expect(valueOf(wrapper, 0)).toBe('1');
    });
  });
});
