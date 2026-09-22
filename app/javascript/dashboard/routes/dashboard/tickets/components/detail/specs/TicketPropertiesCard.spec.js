import { mount } from '@vue/test-utils';
import TicketPropertiesCard from '../TicketPropertiesCard.vue';

const ticket = (overrides = {}) => ({
  id: 1,
  display_id: 12,
  status: 'open',
  priority: 'medium',
  team_id: 7,
  team_name: 'suporte',
  ticket_column_id: 3,
  assignee_id: null,
  ...overrides,
});

const columns = [
  { id: 3, name: 'A fazer' },
  { id: 4, name: 'Em andamento' },
];

const categories = [
  { id: 20, name: 'Erro' },
  { id: 21, name: 'Dúvida' },
];

const agents = [
  { id: 9, name: 'Ana', thumbnail: '' },
  { id: 10, name: 'Bruno', thumbnail: '' },
];

const mountCard = (props = {}) =>
  mount(TicketPropertiesCard, {
    props: { ticket: ticket(), columns, categories, agents, ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Avatar: true,
        // Espelha o contrato do TicketSelect, o seletor padrao do modulo: cada
        // campo expoe as opcoes e devolve o valor escolhido.
        TicketSelect: {
          props: {
            modelValue: { type: [Number, String, Array], default: null },
            options: { type: Array, default: () => [] },
            clearable: { type: Boolean, default: false },
            clearLabel: { type: String, default: '' },
            disabled: { type: Boolean, default: false },
          },
          emits: ['update:modelValue'],
          template: `<div class="ticket-select" :data-disabled="String(disabled)">
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
      },
    },
  });

// [0] priority, [1] status, [2] stage, [3] category, [4] assignee
const selects = wrapper => wrapper.findAll('.ticket-select');

// Escolher uma opcao pelo valor, dentro de um dos campos.
const choose = async (wrapper, index, value) => {
  const field = selects(wrapper)[index];
  await field.find(`[data-value="${value}"]`).trigger('click');
};

const isDisabled = (wrapper, index) =>
  selects(wrapper)[index].attributes('data-disabled') === 'true';

// As opcoes visiveis de um campo, ignorando a entrada que esvazia.
const optionsOf = (wrapper, index) =>
  selects(wrapper)
    [index].findAll('button')
    .filter(button => button.attributes('data-value') !== '')
    .map(button => button.text());

describe('TicketPropertiesCard', () => {
  it('shows the Mesa read-only, capitalized', () => {
    expect(mountCard().text()).toContain('Suporte');
  });

  it('lists only the stages of this ticket Mesa', () => {
    expect(optionsOf(mountCard(), 2)).toEqual(['A fazer', 'Em andamento']);
  });

  // `optionsOf` ja descarta a entrada que esvazia o campo.
  it('lists only the members of the Mesa as assignees', () => {
    expect(optionsOf(mountCard(), 4)).toEqual(['Ana', 'Bruno']);
  });

  describe('persisting', () => {
    it('sends priority through updateProperty', async () => {
      const wrapper = mountCard();
      await choose(wrapper, 0, 'urgent');

      expect(wrapper.emitted('updateProperty')).toEqual([
        [{ priority: 'urgent' }],
      ]);
    });

    // Status has no generic setter - the model's resolve!/close!/reopen! are
    // what write resolved_at/closed_at and the activity.
    it('routes status through changeStatus, never updateProperty', async () => {
      const wrapper = mountCard();
      await choose(wrapper, 1, 'resolved');

      expect(wrapper.emitted('changeStatus')).toEqual([['resolved']]);
      expect(wrapper.emitted('updateProperty')).toBeUndefined();
    });

    // `update` strips ticket_column_id; only `move` keeps team_id in lockstep.
    it('routes stage through moveToColumn, never updateProperty', async () => {
      const wrapper = mountCard();
      await choose(wrapper, 2, '4');

      expect(wrapper.emitted('moveToColumn')).toEqual([[4]]);
      expect(wrapper.emitted('updateProperty')).toBeUndefined();
    });

    it('sends the assignee as a number, and null to unassign', async () => {
      const wrapper = mountCard();
      await choose(wrapper, 4, '10');
      await choose(wrapper, 4, '');

      expect(wrapper.emitted('updateProperty')).toEqual([
        [{ assignee_id: 10 }],
        [{ assignee_id: null }],
      ]);
    });
  });

  // Categoria belongs to the Mesa, exactly like the Estagio - and is distinct
  // from the Catalogo de Servicos, which classifies the attendance.
  describe('the Categoria', () => {
    it('lists only the categories of this ticket Mesa', () => {
      expect(optionsOf(mountCard(), 3)).toEqual(['Erro', 'Dúvida']);
    });

    it('persists straight away, as a number', async () => {
      const wrapper = mountCard();

      await choose(wrapper, 3, '21');

      expect(wrapper.emitted('updateProperty')).toEqual([
        [{ ticket_category_id: 21 }],
      ]);
    });

    // Sem categoria, o campo oferece a entrada que o deixa vazio.
    it('offers a placeholder when the ticket has none', () => {
      const wrapper = mountCard({
        ticket: ticket({ ticket_category_id: null }),
      });

      expect(selects(wrapper)[3].find('[data-value=""]').exists()).toBe(true);
    });

    it('is disabled until the categories have loaded', () => {
      const wrapper = mountCard({ categories: [] });

      expect(isDisabled(wrapper, 3)).toBe(true);
    });
  });

  // Followers and Origin moved into this card instead of taking cards of their
  // own.
  describe('the context at the foot of the card', () => {
    it('lists the followers by name', () => {
      const wrapper = mountCard({
        ticket: ticket({
          followers: [
            { id: 1, name: 'Ana' },
            { id: 2, name: 'Bruno' },
          ],
        }),
      });

      expect(wrapper.text()).toContain('Ana, Bruno');
    });

    it('says the origin is manual when no conversation is linked', () => {
      expect(mountCard().text()).toContain('ORIGIN.MANUAL');
    });

    it('names the inbox when the ticket came from a chat', () => {
      const wrapper = mountCard({
        ticket: ticket({
          conversations: [{ id: 1, inbox_name: 'WhatsApp Suporte' }],
        }),
      });

      expect(wrapper.text()).toContain('WhatsApp Suporte');
    });
  });

  describe('without permission', () => {
    it('disables every control instead of failing on save', () => {
      const wrapper = mountCard({ canUpdate: false });

      selects(wrapper).forEach(select =>
        expect(select.attributes('data-disabled')).toBe('true')
      );
    });
  });

  it('disables the stage select until the stages have loaded', () => {
    const wrapper = mountCard({ columns: [] });

    expect(isDisabled(wrapper, 2)).toBe(true);
  });

  // Quantos niveis a Mesa usa e configuracao, e a tela desenha um campo por
  // nivel. Antes eram dois campos escritos a mao, e o terceiro nivel nao tinha
  // como aparecer.
  describe('niveis de responsavel', () => {
    const comNiveis = (levels, overrides = {}) =>
      mountCard({
        usesAssigneeLevels: true,
        assigneeLevels: levels,
        agents: [
          { id: 9, name: 'Ana', thumbnail: '', levels: [1] },
          { id: 10, name: 'Bruno', thumbnail: '', levels: [2] },
          { id: 11, name: 'Carla', thumbnail: '', levels: [3] },
        ],
        ...overrides,
      });

    it('shows one assignee field per level of the desk', () => {
      // [0] prioridade, [1] status, [2] estagio, [3] categoria, depois um por nivel
      expect(selects(comNiveis([1, 2])).length).toBe(6);
      expect(selects(comNiveis([1, 2, 3])).length).toBe(7);
    });

    it('offers only the agents enabled for that level', () => {
      const wrapper = comNiveis([1, 2, 3]);
      const nivel3 = selects(wrapper)[6];

      expect(nivel3.findAll('[data-value]').map(node => node.text())).toContain(
        'Carla'
      );
      expect(
        nivel3.findAll('[data-value]').map(node => node.text())
      ).not.toContain('Bruno');
    });

    it('saves the third level into its own field, not on top of the second', async () => {
      const wrapper = comNiveis([1, 2, 3]);

      await choose(wrapper, 6, 11);

      expect(wrapper.emitted('updateProperty')[0][0]).toEqual({
        assignee_3_id: 11,
      });
    });

    it('keeps the single assignee field on a desk without levels', () => {
      expect(selects(mountCard()).length).toBe(5);
    });
  });
});
