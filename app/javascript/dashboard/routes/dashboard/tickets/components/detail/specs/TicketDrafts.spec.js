import { mount, flushPromises } from '@vue/test-utils';
import TicketCommunicationTab from '../TicketCommunicationTab.vue';
import TicketCustomerCommunication from '../TicketCustomerCommunication.vue';
import TicketCloseDialog from '../actions/TicketCloseDialog.vue';
import TicketComments from '../../TicketComments.vue';
import { useAlert } from 'dashboard/composables';
import { reloadDrafts } from 'dashboard/helper/textDrafts';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/contacts', () => ({
  default: { getAttendance: vi.fn(() => Promise.resolve({ data: {} })) },
}));

const dispatch = vi.fn(() => Promise.resolve());
const $store = {
  dispatch: (...args) => dispatch(...args),
  getters: {
    getCurrentAccountId: 1,
    getCurrentUserID: 9,
    getCannedResponses: [],
    'tickets/getComments': () => [],
    'tickets/getUIFlags': {},
    'serviceCatalogs/getActiveCatalogs': [],
    'teams/getTeams': [],
    'ticketColumns/getCategories': () => [],
    'ticketColumns/getColumns': () => [],
  },
};

const campoDeTexto = {
  props: { modelValue: { type: String, default: '' } },
  emits: ['update:modelValue'],
  template:
    '<textarea class="corpo" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
};

const global = {
  mocks: { $t: key => key },
  plugins: [
    {
      install: app => {
        app.config.globalProperties.$store = $store;
      },
    },
  ],
  stubs: {
    Icon: true,
    Spinner: true,
    WootLabel: true,
    TicketFileInput: true,
    TicketCatalogSelect: true,
    ComposeConversation: true,
    FullEditor: campoDeTexto,
    Checkbox: true,
    Dialog: {
      template:
        '<div><slot /><button class="confirmar" @click="$emit(\'confirm\')" /></div>',
      methods: { open() {}, close() {} },
    },
    Button: {
      props: { label: { type: String, default: '' } },
      emits: ['click'],
      template:
        '<button type="button" :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
    },
    NextButton: {
      props: { label: { type: String, default: '' } },
      emits: ['click'],
      template:
        '<button type="button" :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
    },
  },
};

const ticket = (overrides = {}) => ({
  id: 7,
  display_id: 70,
  customer_email: 'cliente@exemplo.com',
  customer_communications: [],
  conversations: [],
  missing_close_requirements: [],
  ...overrides,
});

const montar = (component, props) => mount(component, { props, global });
const botao = (wrapper, label) => wrapper.find(`[data-label="${label}"]`);
const aviso = '[data-testid="draft-notice"]';
const chamadas = acao => dispatch.mock.calls.filter(([name]) => name === acao);
const falharEm = acao =>
  dispatch.mockImplementation(name =>
    name === acao
      ? Promise.reject(
          Object.assign(new Error('x'), {
            response: { data: { error: 'recusado' } },
          })
        )
      : Promise.resolve()
  );

beforeEach(() => {
  localStorage.clear();
  reloadDrafts();
  dispatch.mockReset();
  dispatch.mockImplementation(() => Promise.resolve());
  useAlert.mockClear();
});

describe('Comentario interno', () => {
  const comentarios = (ticketId = 7) => montar(TicketComments, { ticketId });
  const campo = wrapper => wrapper.find('textarea');
  const enviar = async wrapper => {
    await botao(wrapper, 'TICKET.COMMENTS.SUBMIT').trigger('click');
    await flushPromises();
  };

  it('volta depois de sair do ticket e so no ticket dele', async () => {
    const first = comentarios();
    await campo(first).setValue('verificar o NCM');
    first.unmount();

    expect(campo(comentarios(8)).element.value).toBe('');
    const wrapper = comentarios();
    expect(campo(wrapper).element.value).toBe('verificar o NCM');
    expect(wrapper.find(aviso).exists()).toBe(true);
  });

  it('com a tela aberta, trocar de ticket troca o texto', async () => {
    const wrapper = comentarios();
    await campo(wrapper).setValue('do 7');

    await wrapper.setProps({ ticketId: 8 });
    expect(campo(wrapper).element.value).toBe('');
    await wrapper.setProps({ ticketId: 7 });
    expect(campo(wrapper).element.value).toBe('do 7');
  });

  it('apaga depois de enviar', async () => {
    const wrapper = comentarios();
    await campo(wrapper).setValue('  feito  ');

    await enviar(wrapper);

    expect(chamadas('tickets/createComment')[0][1].content).toBe('feito');
    expect(campo(wrapper).element.value).toBe('');
    expect(campo(comentarios()).element.value).toBe('');
  });

  it('se o servidor recusar, o texto fica', async () => {
    falharEm('tickets/createComment');
    const wrapper = comentarios();
    await campo(wrapper).setValue('importante');

    await enviar(wrapper);

    expect(campo(wrapper).element.value).toBe('importante');
    expect(campo(comentarios()).element.value).toBe('importante');
  });
});

describe('Mensagem ao cliente', () => {
  const mensagem = (extra = {}) =>
    montar(TicketCustomerCommunication, { ticket: ticket(extra) });
  const campo = wrapper => wrapper.find('textarea.corpo');
  const enviar = async wrapper => {
    await botao(wrapper, 'TICKET.COMMUNICATION.SEND').trigger('click');
    await flushPromises();
  };

  it('volta com o aviso e pode ser descartada', async () => {
    const first = mensagem();
    await campo(first).setValue('<p>Ola</p>');
    first.unmount();

    const wrapper = mensagem();
    expect(campo(wrapper).element.value).toBe('<p>Ola</p>');
    await wrapper.find('[data-testid="draft-discard"]').trigger('click');

    expect(campo(wrapper).element.value).toBe('');
    expect(campo(mensagem()).element.value).toBe('');
  });

  it('apaga so depois de enviada', async () => {
    const wrapper = mensagem();
    await campo(wrapper).setValue('<p>Ola</p>');

    await enviar(wrapper);

    expect(chamadas('tickets/sendCustomerCommunication')[0][1]).toMatchObject({
      ticketId: 7,
      body: '<p>Ola</p>',
    });
    expect(campo(mensagem()).element.value).toBe('');
  });

  it('se o envio falhar, o texto fica', async () => {
    falharEm('tickets/sendCustomerCommunication');
    const wrapper = mensagem();
    await campo(wrapper).setValue('<p>Ola</p>');

    await enviar(wrapper);

    expect(useAlert).toHaveBeenCalledWith('recusado');
    expect(campo(mensagem()).element.value).toBe('<p>Ola</p>');
  });

  it('confirmada depois da troca de ticket, nao apaga o texto do outro', async () => {
    let confirmar;
    dispatch.mockImplementation(name =>
      name === 'tickets/sendCustomerCommunication'
        ? new Promise(resolve => {
            confirmar = resolve;
          })
        : Promise.resolve()
    );
    const wrapper = mensagem();
    await campo(wrapper).setValue('<p>do 7</p>');
    await botao(wrapper, 'TICKET.COMMUNICATION.SEND').trigger('click');
    await wrapper.setProps({ ticket: ticket({ id: 8 }) });
    await campo(wrapper).setValue('<p>do 8</p>');

    confirmar();
    await flushPromises();

    expect(campo(wrapper).element.value).toBe('<p>do 8</p>');
    expect(campo(mensagem()).element.value).toBe('');
  });
});

describe('Aba Comunicacao', () => {
  it('alternar entre nota interna e cliente nao apaga o texto', async () => {
    const wrapper = montar(TicketCommunicationTab, { ticket: ticket() });
    const aba = async nome => {
      await wrapper.find(`[data-channel="${nome}"]`).trigger('click');
    };
    await wrapper.find('textarea').setValue('nota');

    await aba('customer');
    await wrapper.find('textarea.corpo').setValue('<p>cliente</p>');
    await aba('internal');
    expect(wrapper.find('textarea').element.value).toBe('nota');

    await aba('customer');
    expect(wrapper.find('textarea.corpo').element.value).toBe('<p>cliente</p>');
  });

  it('a mensagem ao cliente e a de fechamento sao rascunhos separados', async () => {
    const wrapper = montar(TicketCustomerCommunication, { ticket: ticket() });
    await wrapper.find('textarea.corpo').setValue('<p>andamento</p>');

    const dialog = montar(TicketCloseDialog, {
      ticket: ticket({
        missing_close_requirements: ['customer_communication'],
      }),
    });
    await dialog.vm.open();

    expect(dialog.find('textarea.corpo').element.value).toBe('');
  });
});

describe('Fechar ticket', () => {
  const pendente = () =>
    ticket({
      missing_close_requirements: ['resolution', 'customer_communication'],
    });
  const janela = async (value = pendente()) => {
    const wrapper = montar(TicketCloseDialog, { ticket: value });
    await wrapper.vm.open();
    return wrapper;
  };
  const resolucao = wrapper => wrapper.find('textarea.resolucao');
  const corpo = wrapper => wrapper.find('textarea.corpo');
  const preencher = async wrapper => {
    await resolucao(wrapper).setValue('Reenviada a nota.');
    await corpo(wrapper).setValue('<p>Concluido</p>');
  };
  const confirmar = async wrapper => {
    await wrapper.find('button.confirmar').trigger('click');
    await flushPromises();
  };

  it('fechar a janela e abrir de novo mantem os dois textos', async () => {
    const wrapper = await janela();
    await preencher(wrapper);
    expect(wrapper.findAll(aviso)).toHaveLength(0);

    await wrapper.vm.open();

    expect(resolucao(wrapper).element.value).toBe('Reenviada a nota.');
    expect(corpo(wrapper).element.value).toBe('<p>Concluido</p>');
    expect(wrapper.findAll(aviso)).toHaveLength(2);
  });

  it('volta tambem numa tela nova, e cada texto se descarta sozinho', async () => {
    const first = await janela();
    await preencher(first);
    first.unmount();

    const wrapper = await janela();
    await wrapper
      .find('[data-field="resolution"] [data-testid="draft-discard"]')
      .trigger('click');

    expect(resolucao(wrapper).element.value).toBe('');
    expect(corpo(wrapper).element.value).toBe('<p>Concluido</p>');
  });

  it('fechado o ticket, nada sobra', async () => {
    const wrapper = await janela();
    await preencher(wrapper);

    await confirmar(wrapper);

    expect(chamadas('tickets/closeTicket')[0][1].resolution).toBe(
      'Reenviada a nota.'
    );
    const reaberta = await janela();
    expect(resolucao(reaberta).element.value).toBe('');
    expect(corpo(reaberta).element.value).toBe('');
  });

  it('se a mensagem for recusada, os dois textos ficam', async () => {
    falharEm('tickets/sendCustomerCommunication');
    const wrapper = await janela();
    await preencher(wrapper);

    await confirmar(wrapper);

    const reaberta = await janela();
    expect(resolucao(reaberta).element.value).toBe('Reenviada a nota.');
    expect(corpo(reaberta).element.value).toBe('<p>Concluido</p>');
  });

  it('mensagem enviada e fechamento recusado: nao envia de novo', async () => {
    falharEm('tickets/closeTicket');
    const wrapper = await janela();
    await preencher(wrapper);

    await confirmar(wrapper);

    expect(corpo(wrapper).exists()).toBe(false);
    expect(wrapper.text()).toContain('TICKET.CLOSE.COMMUNICATION_DONE');
    expect(resolucao(wrapper).element.value).toBe('Reenviada a nota.');

    dispatch.mockImplementation(() => Promise.resolve());
    await confirmar(wrapper);

    expect(chamadas('tickets/sendCustomerCommunication')).toHaveLength(1);
    expect(chamadas('tickets/closeTicket')).toHaveLength(2);
    // Reaberta, a mensagem ja enviada nao volta como rascunho.
    expect(corpo(await janela()).element.value).toBe('');
  });

  it('com a janela aberta, trocar de ticket nao leva os textos', async () => {
    const wrapper = await janela();
    await preencher(wrapper);

    await wrapper.setProps({ ticket: { ...pendente(), id: 8 } });

    expect(resolucao(wrapper).element.value).toBe('');
    expect(corpo(wrapper).element.value).toBe('');
  });
});
