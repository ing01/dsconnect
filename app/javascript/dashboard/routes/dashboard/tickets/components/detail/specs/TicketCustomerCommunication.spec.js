import { mount, flushPromises } from '@vue/test-utils';
import TicketCustomerCommunication from '../TicketCustomerCommunication.vue';

// O flag de envio na aba Comunicacao. Desmarcado, a mensagem e apenas
// REGISTRADA: ela continua visivel para o cliente na Area do Cliente, e nenhum
// e-mail sai. Serve para quando a equipe ja falou com ele por telefone ou
// WhatsApp e quer deixar isso no chamado.
const dispatch = vi.fn(() => Promise.resolve());

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: (...a) => dispatch(...a) }),
}));

const ticket = (overrides = {}) => ({
  id: 7,
  customer_email: 'cliente@exemplo.com',
  customer_communications: [],
  ...overrides,
});

const montar = (props = {}) =>
  mount(TicketCustomerCommunication, {
    props: { ticket: ticket(), ...props },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        WootLabel: {
          props: { label: { type: String, default: '' } },
          template: '<span class="etiqueta">{{ label }}</span>',
        },
        Button: {
          props: {
            label: { type: String, default: '' },
            disabled: { type: Boolean, default: false },
          },
          template:
            '<button class="acao" :data-label="label" :disabled="disabled" @click="$emit(\'click\')" />',
        },
        FullEditor: {
          props: { modelValue: { type: String, default: '' } },
          emits: ['update:modelValue'],
          template:
            '<textarea class="corpo" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        Checkbox: {
          props: { modelValue: { type: Boolean, default: false } },
          emits: ['update:modelValue'],
          template:
            '<input class="notificar" type="checkbox" :checked="modelValue" @change="$emit(\'update:modelValue\', !modelValue)" />',
        },
      },
    },
  });

const enviar = async wrapper => {
  await wrapper.find('textarea.corpo').setValue('<p>Falei com voce</p>');
  await wrapper.find('button.acao').trigger('click');
  await flushPromises();
};

const mensagem = () =>
  dispatch.mock.calls.find(
    ([acao]) => acao === 'tickets/sendCustomerCommunication'
  )?.[1];

const rotuloDoBotao = wrapper =>
  wrapper.find('button.acao').attributes('data-label');

beforeEach(() => dispatch.mockClear());

describe('TicketCustomerCommunication', () => {
  it('sends the e-mail by default', async () => {
    const wrapper = montar();
    await enviar(wrapper);

    expect(mensagem()).toMatchObject({
      closing: false,
      notifyCustomer: true,
    });
  });

  // O ponto central: o que a pessoa desmarcou tem de chegar ao servidor.
  it('registers without e-mail once unchecked', async () => {
    const wrapper = montar();
    await wrapper.find('input.notificar').trigger('change');
    await enviar(wrapper);

    expect(mensagem()).toMatchObject({ notifyCustomer: false });
  });

  // O botao diz o que vai acontecer. "Enviar" sobre algo que nao sai seria a
  // tela afirmando o contrario do que a pessoa acabou de escolher.
  it('renames the button to match the choice', async () => {
    const wrapper = montar();
    expect(rotuloDoBotao(wrapper)).toBe('TICKET.COMMUNICATION.SEND');

    await wrapper.find('input.notificar').trigger('change');

    expect(rotuloDoBotao(wrapper)).toBe('TICKET.COMMUNICATION.REGISTER');
  });

  // `skipped` nao e falha nem pendencia - e escolha de quem enviou, e a lista
  // precisa dizer isso em vez de parecer um erro.
  it('labels a registered message as having no e-mail', () => {
    const wrapper = montar({
      ticket: ticket({
        customer_communications: [
          {
            id: 1,
            status: 'skipped',
            notify_customer: false,
            direction: 'outbound',
            body: 'Falei por telefone',
            user_name: 'Ana',
            to_email: 'cliente@exemplo.com',
            created_at: 1,
          },
        ],
      }),
    });

    const etiquetas = wrapper.findAll('.etiqueta').map(e => e.text());
    expect(etiquetas).toContain('TICKET.COMMUNICATION.STATUS.SKIPPED');
  });
});
