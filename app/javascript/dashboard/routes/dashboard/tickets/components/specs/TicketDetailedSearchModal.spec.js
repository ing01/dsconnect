import { mount, flushPromises } from '@vue/test-utils';
import TicketDetailedSearchModal from '../TicketDetailedSearchModal.vue';

const { holder } = vi.hoisted(() => ({ holder: {} }));

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.dispatch = vi.fn(() => Promise.resolve());
  holder.boards = {
    1: {
      ticket_columns: [
        { id: 11, name: 'A fazer' },
        { id: 12, name: 'Em atendimento' },
      ],
    },
    2: { ticket_columns: [{ id: 21, name: 'Triagem' }] },
  };
  holder.categories = {
    1: [{ id: 91, name: 'Erro' }],
    2: [{ id: 92, name: 'Proposta' }],
  };

  return {
    useStore: () => ({
      dispatch: holder.dispatch,
      getters: {
        'ticketColumns/getBoard': id => holder.boards[id] || null,
        'ticketColumns/getCategories': id => holder.categories[id] || [],
      },
    }),
    useMapGetter: () => ref([{ id: 50, name: 'Ana' }]),
  };
});

vi.mock('dashboard/api/companies', () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: { payload: [] } })),
    search: vi.fn(),
  },
}));
vi.mock('dashboard/api/contacts', () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: { payload: [] } })),
    search: vi.fn(),
  },
}));

// Expõe o que interessa de cada campo: se aceita vários e o que está escolhido.
const ticketSelectStub = {
  props: {
    modelValue: { type: [Number, String, Array], default: null },
    options: { type: Array, default: () => [] },
    multiple: { type: Boolean, default: false },
    clearable: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false },
    ariaLabel: { type: String, default: '' },
  },
  emits: ['update:modelValue'],
  methods: {
    // Espelha o componente real: no multiplo ele devolve a lista ja alternada,
    // no simples devolve o valor.
    pick(value) {
      if (!this.multiple) {
        this.$emit('update:modelValue', value);
        return;
      }

      const current = Array.isArray(this.modelValue) ? this.modelValue : [];
      const next = current.includes(value)
        ? current.filter(item => item !== value)
        : [...current, value];
      this.$emit('update:modelValue', next);
    },
  },
  template: `<div
    class="ticket-select"
    :data-label="ariaLabel"
    :data-multiple="String(multiple)"
    :data-clearable="String(clearable)"
    :data-disabled="String(disabled)"
    :data-model="JSON.stringify(modelValue)"
  >
    <button
      v-for="option in options"
      :key="String(option.value)"
      :data-value="String(option.value)"
      @click="pick(option.value)"
    >{{ option.label }}</button>
  </div>`,
};

const mountModal = async () => {
  const wrapper = mount(TicketDetailedSearchModal, {
    props: {
      teams: [
        { id: 1, name: 'Suporte' },
        { id: 2, name: 'Implantacao' },
      ],
    },
    global: {
      stubs: {
        TicketSelect: ticketSelectStub,
        TicketListView: true,
        NextButton: true,
        'woot-modal-header': true,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const field = (wrapper, label) =>
  wrapper
    .findAll('.ticket-select')
    .find(el => el.attributes('data-label') === label);

const modelOf = (wrapper, label) =>
  JSON.parse(field(wrapper, label).attributes('data-model'));

const choose = async (wrapper, label, value) =>
  field(wrapper, label).find(`[data-value="${value}"]`).trigger('click');

describe('TicketDetailedSearchModal', () => {
  beforeEach(() => vi.clearAllMocks());

  // O Estagio pertence a uma Mesa, entao aceitar varias deixaria aquela lista
  // sem dono definido.
  it('keeps Mesa a single choice', async () => {
    const wrapper = await mountModal();
    const mesa = field(wrapper, 'TICKET.SEARCH.MESA');

    expect(mesa.attributes('data-multiple')).toBe('false');
    // Nenhuma Mesa continua sendo uma resposta valida.
    expect(mesa.attributes('data-clearable')).toBe('true');
    expect(modelOf(wrapper, 'TICKET.SEARCH.MESA')).toBeNull();
  });

  it('keeps every other filter multiple', async () => {
    const wrapper = await mountModal();

    [
      'TICKET.SEARCH.STATUS',
      'TICKET.SEARCH.COMPANY',
      'TICKET.SEARCH.CONTACT',
      'TICKET.SEARCH.ASSIGNEE',
      'TICKET.SEARCH.ESTAGIO',
      'TICKET.FORM.PRIORITY.LABEL',
      'TICKET.CREATE.CATEGORY',
    ].forEach(label =>
      expect(field(wrapper, label).attributes('data-multiple')).toBe('true')
    );
  });

  it('offers only the stages of the chosen Mesa', async () => {
    const wrapper = await mountModal();

    await choose(wrapper, 'TICKET.SEARCH.MESA', '1');
    await flushPromises();

    expect(
      field(wrapper, 'TICKET.SEARCH.ESTAGIO')
        .findAll('button')
        .map(button => button.text())
    ).toEqual(['A fazer', 'Em atendimento']);
  });

  it('clears the chosen stages and categories when the Mesa changes', async () => {
    const wrapper = await mountModal();

    await choose(wrapper, 'TICKET.SEARCH.MESA', '1');
    await flushPromises();
    await choose(wrapper, 'TICKET.SEARCH.ESTAGIO', '11');
    await choose(wrapper, 'TICKET.CREATE.CATEGORY', '91');
    expect(modelOf(wrapper, 'TICKET.SEARCH.ESTAGIO')).toEqual([11]);

    await choose(wrapper, 'TICKET.SEARCH.MESA', '2');
    await flushPromises();

    expect(modelOf(wrapper, 'TICKET.SEARCH.ESTAGIO')).toEqual([]);
    expect(modelOf(wrapper, 'TICKET.CREATE.CATEGORY')).toEqual([]);
  });

  // Trocar a Mesa nao pode levar junto o que nao depende dela.
  it('leaves the other filters alone when the Mesa changes', async () => {
    const wrapper = await mountModal();

    await choose(wrapper, 'TICKET.SEARCH.STATUS', 'open');
    await choose(wrapper, 'TICKET.SEARCH.ASSIGNEE', '50');

    await choose(wrapper, 'TICKET.SEARCH.MESA', '2');
    await flushPromises();

    expect(modelOf(wrapper, 'TICKET.SEARCH.STATUS')).toEqual(['open']);
    expect(modelOf(wrapper, 'TICKET.SEARCH.ASSIGNEE')).toEqual([50]);
  });

  it('keeps stages and categories disabled until a Mesa is chosen', async () => {
    const wrapper = await mountModal();

    expect(
      field(wrapper, 'TICKET.SEARCH.ESTAGIO').attributes('data-disabled')
    ).toBe('true');
    expect(
      field(wrapper, 'TICKET.CREATE.CATEGORY').attributes('data-disabled')
    ).toBe('true');
  });
});
