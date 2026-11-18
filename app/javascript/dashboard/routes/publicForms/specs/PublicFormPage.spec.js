import { mount, flushPromises } from '@vue/test-utils';
import PublicFormPage from '../PublicFormPage.vue';
import PublicFormsAPI from 'dashboard/api/publicForms';

const { routeState } = vi.hoisted(() => ({
  routeState: { params: { token: 'abc123' } },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('vue-router', () => ({ useRoute: () => routeState }));
vi.mock('dashboard/api/publicForms', () => ({
  default: { show: vi.fn(), submit: vi.fn() },
}));

const FORM = {
  id: 1,
  name: 'Aberto',
  description: '',
  success_message: 'Recebemos!',
  fields: [
    { id: 'f1', label: 'Motivo', field_type: 'short_text', required: true },
  ],
};

const ButtonStub = {
  props: ['label', 'disabled'],
  template: '<button :disabled="disabled" v-bind="$attrs">{{ label }}</button>',
};

const mountPage = async () => {
  const wrapper = mount(PublicFormPage, {
    global: { stubs: { Button: ButtonStub } },
  });
  await flushPromises();
  return wrapper;
};

const fillAndSend = async wrapper => {
  await wrapper.find('[data-testid="field-f1"] input').setValue('Oi');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
};

describe('PublicFormPage', () => {
  beforeEach(() => vi.clearAllMocks());

  it('loads the form by the code of the link', async () => {
    PublicFormsAPI.show.mockResolvedValue({ data: FORM });
    const wrapper = await mountPage();

    expect(PublicFormsAPI.show).toHaveBeenCalledWith('abc123');
    expect(wrapper.text()).toContain('Aberto');
  });

  it('says so when the form does not exist or is not open', async () => {
    PublicFormsAPI.show.mockRejectedValue({ response: { status: 404 } });
    const wrapper = await mountPage();

    expect(wrapper.find('[data-testid="form-not-found"]').exists()).toBe(true);
    expect(wrapper.find('form').exists()).toBe(false);
  });

  it('sends the answers and shows the message of the form', async () => {
    PublicFormsAPI.show.mockResolvedValue({ data: FORM });
    PublicFormsAPI.submit.mockResolvedValue({
      data: { success_message: 'Recebemos!' },
    });
    const wrapper = await mountPage();

    await fillAndSend(wrapper);

    expect(PublicFormsAPI.submit).toHaveBeenCalledWith(
      'abc123',
      expect.objectContaining({ answers: { f1: 'Oi' } })
    );
    expect(wrapper.find('[data-testid="form-done"]').text()).toContain(
      'Recebemos!'
    );
  });

  it('shows the error of the server and keeps the form on the screen', async () => {
    PublicFormsAPI.show.mockResolvedValue({ data: FORM });
    PublicFormsAPI.submit.mockRejectedValue({
      response: { status: 422, data: { message: 'preencha: Motivo' } },
    });
    const wrapper = await mountPage();

    await fillAndSend(wrapper);

    expect(wrapper.find('[data-testid="form-error"]').text()).toBe(
      'preencha: Motivo'
    );
    expect(wrapper.find('[data-testid="form-done"]').exists()).toBe(false);
  });

  it('tells the visitor to wait when the send limit is reached', async () => {
    PublicFormsAPI.show.mockResolvedValue({ data: FORM });
    PublicFormsAPI.submit.mockRejectedValue({ response: { status: 429 } });
    const wrapper = await mountPage();

    await fillAndSend(wrapper);

    expect(wrapper.find('[data-testid="form-error"]').text()).toBe(
      'FORMS.FILL.TOO_MANY'
    );
  });

  it('can send another answer after the first, starting empty', async () => {
    PublicFormsAPI.show.mockResolvedValue({ data: FORM });
    PublicFormsAPI.submit.mockResolvedValue({ data: {} });
    const wrapper = await mountPage();
    await fillAndSend(wrapper);

    await wrapper.find('[data-testid="form-done"] button').trigger('click');

    expect(wrapper.find('form').exists()).toBe(true);
    expect(wrapper.find('[data-testid="field-f1"] input').element.value).toBe(
      ''
    );
  });
});
