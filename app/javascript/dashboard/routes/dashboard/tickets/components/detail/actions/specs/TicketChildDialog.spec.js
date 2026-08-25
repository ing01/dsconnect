import { mount } from '@vue/test-utils';
import TicketChildDialog from '../TicketChildDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

// A parent with something to copy in every category, so each option is offered.
const fullTicket = (overrides = {}) => ({
  id: 1,
  title: 'Erro na emissao de NF',
  description: 'detalhes',
  company_id: 7,
  team_id: 3,
  assignee_id: 9,
  followers: [{ id: 1, user_id: 9, name: 'Ana' }],
  attachments: [{ id: 1 }],
  conversations: [{ id: 4, display_id: 2 }],
  ...overrides,
});

const mountDialog = async (ticket = fullTicket()) => {
  const wrapper = mount(TicketChildDialog, {
    props: { ticket },
    global: {
      stubs: {
        Dialog: {
          template:
            '<div><slot /><button class="confirm" @click="$emit(\'confirm\')" /></div>',
          methods: { open() {}, close() {} },
        },
      },
    },
  });
  await wrapper.vm.open();
  return wrapper;
};

const boxes = wrapper => wrapper.findAll('input[type="checkbox"]');
// [0] is "Selecionar todos"; the rest are the options, in declaration order.
const optionBoxes = wrapper => boxes(wrapper).slice(1);
const selectAll = wrapper => boxes(wrapper)[0];

const labels = wrapper =>
  wrapper
    .findAll('label')
    .slice(1)
    .map(label => label.text());

const submit = async wrapper => {
  await wrapper.find('.confirm').trigger('click');
  return wrapper.emitted('submit')[0][0].options;
};

describe('TicketChildDialog', () => {
  it('starts with nothing ticked', async () => {
    const wrapper = await mountDialog();

    expect(optionBoxes(wrapper).every(box => !box.element.checked)).toBe(true);
  });

  it('sends only the options that were ticked', async () => {
    const wrapper = await mountDialog();
    await optionBoxes(wrapper)[0].setValue(true);

    const options = await submit(wrapper);

    expect(options).toEqual({ title: true });
  });

  // There is no Solicitante checkbox: a Ticket has no contact FK, so copying it
  // on its own is not expressible - it travels with the conversations.
  it('offers no Solicitante option', async () => {
    const wrapper = await mountDialog();

    expect(labels(wrapper).join(' ')).not.toContain('REQUESTER');
  });

  describe('options with nothing to copy', () => {
    it('hides Empresa when the parent has none', async () => {
      const wrapper = await mountDialog(fullTicket({ company_id: null }));

      expect(labels(wrapper).join(' ')).not.toContain('OPTIONS.COMPANY');
    });

    it('hides Arquivos when the parent has none', async () => {
      const wrapper = await mountDialog(fullTicket({ attachments: [] }));

      expect(labels(wrapper).join(' ')).not.toContain('OPTIONS.ATTACHMENTS');
    });

    it('hides Comunicacao com cliente when no conversation is linked', async () => {
      const wrapper = await mountDialog(fullTicket({ conversations: [] }));

      expect(labels(wrapper).join(' ')).not.toContain('OPTIONS.CONVERSATIONS');
    });
  });

  describe('dependencies', () => {
    // The only real dependency in this model: a Responsavel is valid only
    // inside the Mesa the ticket sits in.
    it('disables Responsavel until Mesa is ticked', async () => {
      const wrapper = await mountDialog();
      const assignee = optionBoxes(wrapper)[4];

      expect(assignee.attributes('disabled')).toBeDefined();
    });

    it('enables it once Mesa is ticked', async () => {
      const wrapper = await mountDialog();
      await optionBoxes(wrapper)[3].setValue(true);

      expect(optionBoxes(wrapper)[4].attributes('disabled')).toBeUndefined();
    });

    // Otherwise the payload would ask to copy a Responsavel without the Mesa
    // that makes them valid.
    it('drops Responsavel again when Mesa is unticked', async () => {
      const wrapper = await mountDialog();
      await optionBoxes(wrapper)[3].setValue(true);
      await optionBoxes(wrapper)[4].setValue(true);
      await optionBoxes(wrapper)[3].setValue(false);

      const options = await submit(wrapper);

      expect(options.team).toBeFalsy();
      expect(options.assignee).toBeUndefined();
    });
  });

  describe('selecionar todos', () => {
    // Ticking `team` makes `assignee` available, which was not in the list on
    // the first pass - so the selection is applied until it settles.
    it('reaches the options that only become available along the way', async () => {
      const wrapper = await mountDialog();

      await selectAll(wrapper).setValue(true);
      const options = await submit(wrapper);

      expect(options.team).toBe(true);
      expect(options.assignee).toBe(true);
      expect(options.conversations).toBe(true);
    });

    it('clears everything when unticked', async () => {
      const wrapper = await mountDialog();
      await selectAll(wrapper).setValue(true);

      await selectAll(wrapper).setValue(false);
      const options = await submit(wrapper);

      expect(options).toEqual({});
    });

    it('reflects the state when the options are ticked one by one', async () => {
      const wrapper = await mountDialog(
        fullTicket({
          description: null,
          company_id: null,
          assignee_id: null,
          followers: [],
          attachments: [],
          conversations: [],
        })
      );

      // Only Titulo, Mesa and Comunicacao interna remain available.
      const remaining = optionBoxes(wrapper);
      await Promise.all(remaining.map(box => box.setValue(true)));

      expect(selectAll(wrapper).element.checked).toBe(true);
    });
  });
});
