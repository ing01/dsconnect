import { mount, flushPromises } from '@vue/test-utils';
import TicketCloseDialog from '../TicketCloseDialog.vue';

// Dois assuntos vivem aqui.
//
// O primeiro: o campo da mensagem nao pode ficar dentro de um `<label>`. O
// `FullEditor` traz dentro dele um `<input type="file" hidden>` - o envio de
// imagem do editor de artigos - e um `label` ao redor faz QUALQUER clique na
// area da mensagem ativar esse input, abrindo a tela de enviar arquivo do
// sistema. Anexo nunca foi pedido aqui.
//
// O segundo: o flag de e-mail. Desmarcado, a mensagem de encerramento e apenas
// REGISTRADA - o cliente ve o texto na Area do Cliente e nenhum e-mail sai -, e
// o que a pessoa desmarcou tem de chegar ao servidor.
const dispatch = vi.fn(() => Promise.resolve());

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: (...a) => dispatch(...a) }),
  useMapGetter: () => ({ value: [] }),
}));

const ticket = (overrides = {}) => ({
  id: 1,
  display_id: 42,
  customer_email: 'cliente@exemplo.com',
  display_subject: '#42 - Erro na emissao',
  missing_close_requirements: ['customer_communication'],
  ...overrides,
});

const montar = async (props = {}) => {
  const wrapper = mount(TicketCloseDialog, {
    props: { ticket: ticket(), ...props },
    global: {
      stubs: {
        Dialog: {
          template:
            '<div><slot /><button class="confirmar" @click="$emit(\'confirm\')" /></div>',
          methods: { open() {}, close() {} },
        },
        Icon: true,
        TicketCatalogSelect: true,
        // O mesmo formato do componente real: o input de arquivo escondido e a
        // razao pela qual o `label` era um problema.
        FullEditor: {
          props: { modelValue: { type: String, default: '' } },
          emits: ['update:modelValue'],
          template:
            '<div class="editor"><input type="file" hidden /><textarea class="corpo" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" /></div>',
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
  await wrapper.vm.open();
  return wrapper;
};

// O corpo e obrigatorio: sem ele o botao de confirmar nao faz nada.
const escrever = wrapper =>
  wrapper.find('textarea.corpo').setValue('<p>Concluido</p>');

const fechar = async wrapper => {
  await escrever(wrapper);
  await wrapper.find('button.confirmar').trigger('click');
  await flushPromises();
};

const mensagemEnviada = () =>
  dispatch.mock.calls.find(
    ([acao]) => acao === 'tickets/sendCustomerCommunication'
  )?.[1];

beforeEach(() => dispatch.mockClear());

describe('TicketCloseDialog', () => {
  it('does not put the message editor inside a label', async () => {
    const wrapper = await montar();

    expect(wrapper.find('.editor').exists()).toBe(true);
    expect(
      wrapper.findAll('label').some(l => l.find('input[type="file"]').exists())
    ).toBe(false);
  });

  // Sem endereco nao ha mensagem, e sem mensagem nao ha editor - nem input de
  // arquivo nenhum na tela.
  it('offers no editor when the requester has no address', async () => {
    const wrapper = await montar({
      ticket: ticket({
        missing_close_requirements: ['customer_communication', 'contact_email'],
      }),
    });

    expect(wrapper.find('.editor').exists()).toBe(false);
  });

  describe('o flag de e-mail', () => {
    it('comes checked, so the usual case sends the e-mail', async () => {
      const wrapper = await montar();
      await fechar(wrapper);

      expect(mensagemEnviada()).toMatchObject({
        closing: true,
        notifyCustomer: true,
      });
    });

    // O ponto central: sem isto o flag seria enfeite e o e-mail sairia igual.
    it('travels as false once unchecked', async () => {
      const wrapper = await montar();
      await wrapper.find('input.notificar').trigger('change');
      await fechar(wrapper);

      expect(mensagemEnviada()).toMatchObject({ notifyCustomer: false });
    });

    // A mensagem registrada tambem fecha o ticket - e o servidor que trata os
    // dois casos como comunicacao cumprida.
    it('still closes the ticket', async () => {
      const wrapper = await montar();
      await wrapper.find('input.notificar').trigger('change');
      await fechar(wrapper);

      expect(dispatch).toHaveBeenCalledWith('tickets/closeTicket', 1);
    });

    // Sem envio nao ha destinatario nem assunto, e mostra-los descreveria uma
    // mensagem que nao vai sair.
    it('stops showing recipient and subject when nothing will be e-mailed', async () => {
      const wrapper = await montar();
      expect(wrapper.text()).toContain('cliente@exemplo.com');

      await wrapper.find('input.notificar').trigger('change');

      expect(wrapper.text()).not.toContain('cliente@exemplo.com');
    });
  });
});
