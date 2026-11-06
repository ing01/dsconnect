import { mount } from '@vue/test-utils';
import TicketCancelDialog from '../actions/TicketCancelDialog.vue';

const mountDialog = () =>
  mount(TicketCancelDialog, {
    props: { ticket: { id: 1, display_id: 26 } },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Dialog: {
          emits: ['confirm'],
          props: ['disableConfirmButton'],
          methods: { open() {}, close() {} },
          template:
            '<div><slot /><button class="confirm" :disabled="disableConfirmButton" @click="$emit(\'confirm\')" /></div>',
        },
      },
    },
  });

describe('TicketCancelDialog', () => {
  it('blocks confirming until a reason is written', async () => {
    const wrapper = mountDialog();
    expect(wrapper.find('.confirm').attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('   ');
    expect(wrapper.find('.confirm').attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('Chamado duplicado');
    expect(wrapper.find('.confirm').attributes('disabled')).toBeUndefined();
  });

  it('submits only the trimmed reason', async () => {
    const wrapper = mountDialog();
    await wrapper.find('textarea').setValue('  Aberto por engano  ');
    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('submit')).toEqual([['Aberto por engano']]);
  });
});
