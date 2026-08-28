import { mount, flushPromises } from '@vue/test-utils';
import TicketTransferDialog from '../TicketTransferDialog.vue';

const { dispatch, getters, holder } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  getters: {},
  holder: {},
}));

// `useMapGetter` has to hand back a genuine ref: the template only unwraps
// real refs, so a plain { value: [] } would render as an empty list.
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.teams = ref([]);
  return {
    useStore: () => ({ dispatch, getters }),
    useMapGetter: () => holder.teams,
  };
});

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

// The Estagios and the members of each Mesa, keyed by team id. The whole point
// of the guided order is that picking a Mesa changes what these two offer.
const COLUMNS = {
  1: [
    { id: 10, name: 'A fazer' },
    { id: 11, name: 'Em andamento' },
  ],
  2: [{ id: 20, name: 'Triagem' }],
};
const MEMBERS = {
  1: [{ id: 100, name: 'Ana' }],
  2: [
    { id: 200, name: 'Bruno' },
    { id: 201, name: 'Carla' },
  ],
};

const ticket = (overrides = {}) => ({
  id: 5,
  team_id: 1,
  ticket_column_id: 10,
  status: 'open',
  priority: 'medium',
  assignee_id: null,
  ...overrides,
});

const mountDialog = async (props = {}) => {
  const wrapper = mount(TicketTransferDialog, {
    props: { ticket: ticket(), ...props },
    global: {
      stubs: {
        // Espelha o TicketSelect, o seletor padrao do modulo.
        TicketSelect: {
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
        },
        // Renders the body unconditionally and exposes confirm, so the form can
        // be driven without the real dialog's teleport.
        Dialog: {
          template:
            '<div><slot /><button class="confirm" @click="$emit(\'confirm\')" /></div>',
          methods: { open() {}, close() {} },
        },
      },
    },
  });
  await wrapper.vm.open();
  await flushPromises();
  return wrapper;
};

// [0] Mesa, [1] Estagio, [2] Status, [3] Prioridade, [4] Responsavel
const selects = wrapper => wrapper.findAll('.ticket-select');

const valueOf = (wrapper, index) =>
  selects(wrapper)[index].attributes('data-model');

const choose = async (wrapper, index, value) =>
  selects(wrapper)[index].find(`[data-value="${value}"]`).trigger('click');

// As opcoes visiveis, sem a entrada que esvazia o campo.
const optionsOf = (wrapper, index) =>
  selects(wrapper)
    [index].findAll('button')
    .filter(button => button.attributes('data-value') !== '')
    .map(button => button.text());

describe('TicketTransferDialog', () => {
  beforeEach(() => {
    dispatch.mockClear();
    holder.teams.value = [
      { id: 1, name: 'Suporte' },
      { id: 2, name: 'Implantacao' },
    ];
    getters['ticketColumns/getColumns'] = id => COLUMNS[id] || [];
    getters['teamMembers/getTeamMembers'] = id => MEMBERS[id] || [];
  });

  it('opens on the ticket current Mesa, Estagio, status and priority', async () => {
    const wrapper = await mountDialog({
      ticket: ticket({ priority: 'high', assignee_id: 100 }),
    });

    expect(valueOf(wrapper, 0)).toBe('1');
    expect(valueOf(wrapper, 1)).toBe('10');
    expect(valueOf(wrapper, 3)).toBe('high');
    expect(valueOf(wrapper, 4)).toBe('100');
  });

  it('follows the guided order: Mesa, Estagio, status, prioridade, responsavel', async () => {
    expect(selects(await mountDialog()).length).toBe(5);
  });

  describe('the Mesa drives the two dependent fields', () => {
    it('lists only the Estagios of the selected Mesa', async () => {
      const wrapper = await mountDialog();

      expect(optionsOf(wrapper, 1)).toEqual(['A fazer', 'Em andamento']);

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(optionsOf(wrapper, 1)).toEqual(['Triagem']);
    });

    it('lists only the members of the selected Mesa', async () => {
      const wrapper = await mountDialog();

      await choose(wrapper, 0, '2');
      await flushPromises();

      // The first entry is the "no assignee" placeholder.
      expect(optionsOf(wrapper, 4)).toEqual(['Bruno', 'Carla']);
    });

    it('loads the Estagios and members of a newly chosen Mesa', async () => {
      const wrapper = await mountDialog();
      dispatch.mockClear();

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('ticketColumns/fetchColumns', 2);
      expect(dispatch).toHaveBeenCalledWith('teamMembers/get', { teamId: 2 });
    });

    // Keeping a stale id would submit an Estagio belonging to another Mesa,
    // which the server rejects anyway.
    it('drops the previous Responsavel when the Mesa changes', async () => {
      const wrapper = await mountDialog({
        ticket: ticket({ assignee_id: 100 }),
      });

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(valueOf(wrapper, 4)).toBe('');
    });

    it('defaults to the first Estagio of the new Mesa', async () => {
      const wrapper = await mountDialog();

      await choose(wrapper, 0, '2');
      await flushPromises();

      expect(valueOf(wrapper, 1)).toBe('20');
    });
  });

  it('submits every field the form collected', async () => {
    const wrapper = await mountDialog();

    await choose(wrapper, 2, 'resolved');
    await choose(wrapper, 3, 'urgent');
    await choose(wrapper, 4, '100');
    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      team_id: 1,
      ticket_column_id: 10,
      status: 'resolved',
      priority: 'urgent',
      assignee_id: 100,
    });
  });

  // Transferring to a Mesa without naming an owner is a real intent, so a blank
  // value clears the assignee rather than being dropped.
  it('sends a null assignee when none is chosen', async () => {
    const wrapper = await mountDialog({ ticket: ticket({ assignee_id: 100 }) });

    await choose(wrapper, 4, '');
    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('submit')[0][0].assignee_id).toBeNull();
  });

  it('refuses to submit without an Estagio', async () => {
    getters['ticketColumns/getColumns'] = () => [];
    const wrapper = await mountDialog({
      ticket: ticket({ ticket_column_id: null }),
    });

    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('submit')).toBeUndefined();
  });
});
