import { flushPromises, mount } from '@vue/test-utils';
import ContactsForm from '../ContactsForm.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: { value: { id: 1 } },
    isCloudFeatureEnabled: () => false,
  }),
}));

const montar = () =>
  mount(ContactsForm, {
    props: {
      isDetailsView: true,
      contactData: {
        id: 7,
        name: 'Maria da Silva Souza',
        email: 'maria@exemplo.com',
        phoneNumber: '+5518999990000',
        companies: [],
        additionalAttributes: {
          description: 'bio antiga',
          city: 'Prudente',
          country: 'Brasil',
          countryCode: 'BR',
        },
      },
    },
    global: {
      stubs: {
        Input: true,
        PhoneNumberInput: true,
        ContactCompaniesField: true,
      },
    },
  });

describe('ContactsForm', () => {
  it('mostra so nome, e-mail, telefone (e empresa)', () => {
    const wrapper = montar();
    const placeholders = wrapper
      .findAllComponents({ name: 'Input' })
      .map(input => input.attributes('placeholder'));

    expect(placeholders).toEqual([
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.NAME.PLACEHOLDER',
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.EMAIL_ADDRESS.PLACEHOLDER',
      'CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.COMPANY_NAME.PLACEHOLDER',
    ]);
    expect(wrapper.text()).not.toContain('LAST_NAME');
    expect(wrapper.text()).not.toContain('COUNTRY');
    expect(wrapper.text()).not.toContain('BIO');
    expect(wrapper.text()).not.toContain('CITY');
  });

  it('mantem o nome completo e os campos escondidos ao editar', async () => {
    const wrapper = montar();
    const nameInput = wrapper.findAllComponents({ name: 'Input' })[0];

    await nameInput.vm.$emit('update:modelValue', 'Maria Souza');
    await flushPromises();

    const [payload] = wrapper.emitted('update').at(-1);
    expect(payload.name).toBe('Maria Souza');
    expect(payload.additionalAttributes.city).toBe('Prudente');
    expect(payload.additionalAttributes.description).toBe('bio antiga');
  });
});
