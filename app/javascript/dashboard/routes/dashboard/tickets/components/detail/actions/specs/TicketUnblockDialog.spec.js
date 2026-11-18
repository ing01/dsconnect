import { mount } from '@vue/test-utils';
import TicketUnblockDialog from '../TicketUnblockDialog.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountDialog = (ticket = {}) =>
  mount(TicketUnblockDialog, {
    props: {
      ticket: {
        id: 1,
        display_id: 10,
        blocked_reason: 'Aguardando',
        ...ticket,
      },
    },
    global: {
      stubs: {
        Dialog: {
          emits: ['confirm'],
          template:
            '<div><slot /><button data-testid="confirm" @click="$emit(\'confirm\')" /></div>',
          methods: { open() {}, close() {} },
        },
      },
    },
  });

describe('TicketUnblockDialog', () => {
  it('asks how the impediment was resolved, as an optional field', () => {
    const wrapper = mountDialog();

    expect(wrapper.find('[data-testid="unblock-resolution"]').exists()).toBe(
      true
    );
  });

  it('sends the resolution (trimmed) with the confirmation', async () => {
    const wrapper = mountDialog();
    await wrapper
      .find('[data-testid="unblock-resolution"]')
      .setValue('  Fornecedor liberou a API  ');

    await wrapper.find('[data-testid="confirm"]').trigger('click');

    expect(wrapper.emitted('submit')).toEqual([['Fornecedor liberou a API']]);
  });

  it('still confirms without a resolution', async () => {
    const wrapper = mountDialog();

    await wrapper.find('[data-testid="confirm"]').trigger('click');

    expect(wrapper.emitted('submit')).toEqual([['']]);
  });

  it('starts the next removal with an empty field', async () => {
    const wrapper = mountDialog();
    const field = wrapper.find('[data-testid="unblock-resolution"]');
    await field.setValue('Primeira');
    await wrapper.find('[data-testid="confirm"]').trigger('click');

    expect(field.element.value).toBe('');
  });
});
