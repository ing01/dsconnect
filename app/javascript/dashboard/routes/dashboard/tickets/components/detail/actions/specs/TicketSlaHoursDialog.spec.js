import { mount } from '@vue/test-utils';
import TicketSlaHoursDialog from '../TicketSlaHoursDialog.vue';

const { holder } = vi.hoisted(() => ({ holder: {} }));

// A genuine ref: the template only unwraps real refs.
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  holder.user = ref({ id: 9, name: 'João Vitor' });
  return { useMapGetter: () => holder.user };
});

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const ticket = (overrides = {}) => ({
  id: 5,
  due_at: null,
  sla_extensions: [],
  ...overrides,
});

// The stub keeps the confirm button enabled so the component's own guard is
// what gets tested, not the Dialog's disabled prop.
const mountDialog = async (props = {}) => {
  const wrapper = mount(TicketSlaHoursDialog, {
    props: { ticket: ticket(), ...props },
    global: {
      stubs: {
        Dialog: {
          props: ['disableConfirmButton'],
          template:
            '<div><slot /><button class="confirm" :data-disabled="String(!!disableConfirmButton)" @click="$emit(\'confirm\')" /></div>',
          methods: { open() {}, close() {} },
        },
        Icon: true,
      },
    },
  });
  await wrapper.vm.open();
  return wrapper;
};

const hoursInput = wrapper => wrapper.find('input[type="number"]');
const reasonInput = wrapper => wrapper.find('textarea');
const confirm = wrapper => wrapper.find('.confirm');

const fill = async (wrapper, hours, reason) => {
  await hoursInput(wrapper).setValue(hours);
  await reasonInput(wrapper).setValue(reason);
};

describe('TicketSlaHoursDialog', () => {
  it('fills the attendant from the session, read-only', async () => {
    const wrapper = await mountDialog();
    const agent = wrapper.find('input[type="text"]');

    expect(agent.element.value).toBe('João Vitor');
    expect(agent.attributes('disabled')).toBeDefined();
  });

  describe('validation', () => {
    it('refuses to submit with neither field', async () => {
      const wrapper = await mountDialog();

      await confirm(wrapper).trigger('click');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('requires the reason', async () => {
      const wrapper = await mountDialog();
      await fill(wrapper, '2', '   ');

      await confirm(wrapper).trigger('click');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('requires the hours', async () => {
      const wrapper = await mountDialog();
      await reasonInput(wrapper).setValue('Cliente pediu prazo');

      await confirm(wrapper).trigger('click');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('refuses zero and negative hours', async () => {
      const wrapper = await mountDialog();

      await fill(wrapper, '0', 'motivo');
      await confirm(wrapper).trigger('click');
      await fill(wrapper, '-3', 'motivo');
      await confirm(wrapper).trigger('click');

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('disables the confirm button until both fields are valid', async () => {
      const wrapper = await mountDialog();
      expect(confirm(wrapper).attributes('data-disabled')).toBe('true');

      await fill(wrapper, '2', 'motivo');

      expect(confirm(wrapper).attributes('data-disabled')).toBe('false');
    });
  });

  it('submits the hours as a number and the trimmed reason', async () => {
    const wrapper = await mountDialog();
    await fill(wrapper, '2', '  Cliente solicitou prazo adicional  ');

    await confirm(wrapper).trigger('click');

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      hours: 2,
      reason: 'Cliente solicitou prazo adicional',
    });
  });

  // Half-hour extensions are ordinary, so decimals are accepted.
  it('accepts decimal hours', async () => {
    const wrapper = await mountDialog();
    await fill(wrapper, '1.5', 'meia hora a mais');

    await confirm(wrapper).trigger('click');

    expect(wrapper.emitted('submit')[0][0].hours).toBe(1.5);
  });

  describe('the history', () => {
    it('says there is none rather than showing an empty table', async () => {
      const wrapper = await mountDialog();

      expect(wrapper.text()).toContain('SLA_DIALOG.NO_HISTORY');
      expect(wrapper.find('table').exists()).toBe(false);
    });

    it('lists every extension with hours, reason and who granted it', async () => {
      const wrapper = await mountDialog({
        ticket: ticket({
          sla_extensions: [
            {
              id: 2,
              hours: 4,
              reason: 'Cliente em reuniao',
              user_name: 'Maria',
            },
            { id: 1, hours: 2, reason: 'Aguardando backup', user_name: 'João' },
          ],
        }),
      });

      const rows = wrapper.findAll('tbody tr');
      expect(rows).toHaveLength(2);
      expect(rows[0].text()).toContain('SLA.HOURS_COUNT');
      expect(rows[0].text()).toContain('Cliente em reuniao');
      expect(rows[0].text()).toContain('Maria');
    });
  });

  it('states when the ticket has no deadline yet', async () => {
    const wrapper = await mountDialog();

    expect(wrapper.text()).toContain('SLA_DIALOG.NO_DUE');
  });
});
