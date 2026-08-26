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
      stubs: { Avatar: true },
    },
  });

// [0] priority, [1] status, [2] stage, [3] category, [4] assignee
const selects = wrapper => wrapper.findAll('select');

describe('TicketPropertiesCard', () => {
  it('shows the Mesa read-only, capitalized', () => {
    expect(mountCard().text()).toContain('Suporte');
  });

  it('lists only the stages of this ticket Mesa', () => {
    const options = selects(mountCard())[2].findAll('option');

    expect(options.map(o => o.text())).toEqual(['A fazer', 'Em andamento']);
  });

  it('lists only the members of the Mesa as assignees', () => {
    const options = selects(mountCard())[4].findAll('option');

    // First entry is the "no assignee" placeholder.
    expect(options.slice(1).map(o => o.text())).toEqual(['Ana', 'Bruno']);
  });

  describe('persisting', () => {
    it('sends priority through updateProperty', async () => {
      const wrapper = mountCard();
      await selects(wrapper)[0].setValue('urgent');

      expect(wrapper.emitted('updateProperty')).toEqual([
        [{ priority: 'urgent' }],
      ]);
    });

    // Status has no generic setter - the model's resolve!/close!/reopen! are
    // what write resolved_at/closed_at and the activity.
    it('routes status through changeStatus, never updateProperty', async () => {
      const wrapper = mountCard();
      await selects(wrapper)[1].setValue('resolved');

      expect(wrapper.emitted('changeStatus')).toEqual([['resolved']]);
      expect(wrapper.emitted('updateProperty')).toBeUndefined();
    });

    // `update` strips ticket_column_id; only `move` keeps team_id in lockstep.
    it('routes stage through moveToColumn, never updateProperty', async () => {
      const wrapper = mountCard();
      await selects(wrapper)[2].setValue('4');

      expect(wrapper.emitted('moveToColumn')).toEqual([[4]]);
      expect(wrapper.emitted('updateProperty')).toBeUndefined();
    });

    it('sends the assignee as a number, and null to unassign', async () => {
      const wrapper = mountCard();
      await selects(wrapper)[4].setValue('10');
      await selects(wrapper)[4].setValue('');

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
      const options = selects(mountCard())[3].findAll('option');

      // First entry is the "no category" placeholder.
      expect(options.slice(1).map(o => o.text())).toEqual(['Erro', 'Dúvida']);
    });

    it('persists straight away, as a number', async () => {
      const wrapper = mountCard();

      await selects(wrapper)[3].setValue('21');

      expect(wrapper.emitted('updateProperty')).toEqual([
        [{ ticket_category_id: 21 }],
      ]);
    });

    it('offers a placeholder when the ticket has none', () => {
      const wrapper = mountCard({ ticket: ticket({ ticket_category_id: null }) });

      expect(selects(wrapper)[3].element.selectedIndex).toBe(0);
    });

    it('is disabled until the categories have loaded', () => {
      const wrapper = mountCard({ categories: [] });

      expect(selects(wrapper)[3].attributes('disabled')).toBeDefined();
    });
  });

  // Followers and Origin moved into this card instead of taking cards of their
  // own.
  describe('the context at the foot of the card', () => {
    it('lists the followers by name', () => {
      const wrapper = mountCard({
        ticket: ticket({ followers: [{ id: 1, name: 'Ana' }, { id: 2, name: 'Bruno' }] }),
      });

      expect(wrapper.text()).toContain('Ana, Bruno');
    });

    it('says the origin is manual when no conversation is linked', () => {
      expect(mountCard().text()).toContain('ORIGIN.MANUAL');
    });

    it('names the inbox when the ticket came from a chat', () => {
      const wrapper = mountCard({
        ticket: ticket({ conversations: [{ id: 1, inbox_name: 'WhatsApp Suporte' }] }),
      });

      expect(wrapper.text()).toContain('WhatsApp Suporte');
    });
  });

  describe('without permission', () => {
    it('disables every control instead of failing on save', () => {
      const wrapper = mountCard({ canUpdate: false });

      selects(wrapper).forEach(select =>
        expect(select.attributes('disabled')).toBeDefined()
      );
    });
  });

  it('disables the stage select until the stages have loaded', () => {
    const wrapper = mountCard({ columns: [] });

    expect(selects(wrapper)[2].attributes('disabled')).toBeDefined();
  });
});
