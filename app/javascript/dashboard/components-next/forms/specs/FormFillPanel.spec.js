import { mount } from '@vue/test-utils';
import FormFillPanel from '../FormFillPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const form = {
  id: 1,
  name: 'Abertura',
  description: 'Passo a passo',
  fields: [
    { id: 'f1', label: 'Motivo', field_type: 'short_text', required: true },
    {
      id: 'f2',
      label: 'Tipo',
      field_type: 'single_choice',
      options: ['Dúvida', 'Erro'],
    },
  ],
};

const ButtonStub = {
  props: ['label', 'disabled'],
  template: '<button :disabled="disabled" v-bind="$attrs">{{ label }}</button>',
};

const mountPanel = (props = {}) =>
  mount(FormFillPanel, {
    props: { form, ...props },
    global: { stubs: { Button: ButtonStub } },
  });

describe('FormFillPanel', () => {
  it('shows the title, the description and the questions', () => {
    const wrapper = mountPanel();

    expect(wrapper.text()).toContain('Abertura');
    expect(wrapper.text()).toContain('Passo a passo');
    expect(wrapper.find('[data-testid="field-f1"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="field-f2"]').exists()).toBe(true);
  });

  it('does not send while a required question is empty, and points at it', async () => {
    const wrapper = mountPanel();

    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.find('[data-testid="error-f1"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="error-f2"]').exists()).toBe(false);
  });

  it('sends the answers when the required ones are filled', async () => {
    const wrapper = mountPanel();

    await wrapper
      .find('[data-testid="field-f1"] input')
      .setValue('Preciso de ajuda');
    await wrapper
      .find('[data-testid="field-f2"] input[value="Erro"]')
      .setValue();
    await wrapper.find('form').trigger('submit');

    const [payload] = wrapper.emitted('submit')[0];
    expect(payload.answers).toEqual({ f1: 'Preciso de ajuda', f2: 'Erro' });
  });

  it('asks name and e-mail, with the trap field, only in the open form', () => {
    const closed = mountPanel();
    expect(closed.find('[data-testid="respondent-name"]').exists()).toBe(false);
    expect(closed.find('[data-testid="form-trap"]').exists()).toBe(false);

    const open = mountPanel({ askRespondent: true });
    expect(open.find('[data-testid="respondent-name"]').exists()).toBe(true);
    expect(open.find('[data-testid="form-trap"]').exists()).toBe(true);
  });

  it('carries the optional name, e-mail and the trap in the payload', async () => {
    const wrapper = mountPanel({ askRespondent: true });

    await wrapper.find('[data-testid="field-f1"] input').setValue('x');
    await wrapper.find('[data-testid="respondent-name"]').setValue(' Maria ');
    await wrapper
      .find('[data-testid="respondent-email"]')
      .setValue('maria@exemplo.com');
    await wrapper.find('form').trigger('submit');

    const [payload] = wrapper.emitted('submit')[0];
    expect(payload).toMatchObject({
      respondentName: 'Maria',
      respondentEmail: 'maria@exemplo.com',
      trap: '',
    });
  });

  it('shows the error of the server and does not send twice while sending', async () => {
    const wrapper = mountPanel({
      errorMessage: 'preencha: Motivo',
      isSubmitting: true,
    });

    expect(wrapper.find('[data-testid="form-error"]').text()).toBe(
      'preencha: Motivo'
    );
    await wrapper.find('[data-testid="field-f1"] input').setValue('x');
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('submit')).toBeUndefined();
  });
});
