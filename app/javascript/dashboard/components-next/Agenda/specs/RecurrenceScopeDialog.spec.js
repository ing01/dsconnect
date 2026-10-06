import { mount } from '@vue/test-utils';
import RecurrenceScopeDialog from '../RecurrenceScopeDialog.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const montar = (props = {}) =>
  mount(RecurrenceScopeDialog, {
    props: { show: true, action: 'update', ...props },
    global: {
      stubs: {
        'woot-modal': { template: '<div><slot /></div>' },
        'woot-modal-header': true,
        NextButton: {
          props: ['label'],
          emits: ['click'],
          template: `<button @click="$emit('click')">{{ label }}</button>`,
        },
      },
    },
  });

describe('RecurrenceScopeDialog', () => {
  it('oferece as 3 opcoes de escopo, com "so esta ocorrencia" marcada por padrao', () => {
    const wrapper = montar();

    const radios = wrapper.findAll('input[type="radio"]');
    expect(radios).toHaveLength(3);
    expect(radios[0].element.checked).toBe(true);
  });

  it('emite o escopo escolhido ao confirmar', async () => {
    const wrapper = montar();

    await wrapper.findAll('input[type="radio"]')[1].setValue(); // 'future'
    await wrapper.find('button:last-of-type').trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([['future']]);
  });

  it('mostra o titulo certo para editar e para excluir', () => {
    const editar = montar({ action: 'update' });
    expect(editar.find('[header-title]').attributes('header-title')).toBe(
      'AGENDA.RECURRENCE_SCOPE.UPDATE_TITLE'
    );

    const excluir = montar({ action: 'destroy' });
    expect(excluir.find('[header-title]').attributes('header-title')).toBe(
      'AGENDA.RECURRENCE_SCOPE.DESTROY_TITLE'
    );
  });

  it('emite close ao cancelar', async () => {
    const wrapper = montar();

    await wrapper.find('button:first-of-type').trigger('click');

    expect(wrapper.emitted('close')).toBeTruthy();
  });
});
