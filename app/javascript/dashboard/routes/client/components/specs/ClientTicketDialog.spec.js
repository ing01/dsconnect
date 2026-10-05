import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import ClientTicketDialog from '../ClientTicketDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const createTicket = vi.fn(() => Promise.resolve({ data: { display_id: 42 } }));
const aiDraftEnabled = vi.fn(() =>
  Promise.resolve({ data: { enabled: true } })
);
const generateTicketDraft = vi.fn(() =>
  Promise.resolve({
    data: { ticket_category_id: 1, title: 'Título', description: 'Descrição' },
  })
);

vi.mock('dashboard/api/clientArea', () => ({
  default: {
    createTicket: (...args) => createTicket(...args),
    aiDraftEnabled: (...args) => aiDraftEnabled(...args),
    generateTicketDraft: (...args) => generateTicketDraft(...args),
  },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// Lista plana: o cliente escolhe o TIPO do problema, não a Mesa. Para onde o
// chamado vai é decisão da triagem.
const categories = [
  { id: 1, name: 'Dúvida' },
  // "Erro" quase sempre precisa de print ou log - por isso exige anexo.
  { id: 2, name: 'Erro', require_attachment: true },
];

// `message` + `messageType: error` é como Input e TextArea apontam o que falta;
// os stubs refletem isso para o teste poder contar os avisos.
const campoComMensagem = tag => ({
  props: {
    modelValue: { type: String, default: '' },
    message: { type: String, default: '' },
  },
  emits: ['update:modelValue'],
  template: `<div>
    <${tag} class="campo" :value="modelValue" @input="$emit('update:modelValue', $event.target.value)" />
    <span v-if="message" class="erro-campo">{{ message }}</span>
  </div>`,
});

const montar = (props = {}) =>
  mount(ClientTicketDialog, {
    props: { categories, ...props },
    global: {
      stubs: {
        // Só interessa que existe, não como grava áudio de verdade - o jsdom
        // não tem as APIs de mídia que o componente real pede.
        AudioRecorder: true,
        // Espelha o contrato do Dialog de components-next: expõe open/close e
        // dispara `confirm` pelo botão.
        Dialog: {
          props: {
            disableConfirmButton: { type: Boolean, default: false },
            isLoading: { type: Boolean, default: false },
          },
          emits: ['confirm'],
          methods: { open() {}, close() {} },
          template: `<div>
            <slot />
            <button
              class="confirmar"
              :disabled="disableConfirmButton"
              @click="$emit('confirm')"
            />
          </div>`,
        },
        Input: campoComMensagem('input'),
        TextArea: campoComMensagem('textarea'),
        TicketSelect: {
          props: {
            modelValue: { type: [Number, String], default: null },
            options: { type: Array, default: () => [] },
            disabled: { type: Boolean, default: false },
            hasError: { type: Boolean, default: false },
          },
          emits: ['update:modelValue'],
          template: `<div class="select" :data-error="String(hasError)">
            <button
              v-for="o in options"
              :key="String(o.value)"
              :data-value="String(o.value)"
              @click="$emit('update:modelValue', o.value)"
            >{{ o.label }}</button>
          </div>`,
        },
        TicketFileInput: true,
      },
    },
  });

// Só resta um select: a Categoria.
const selects = wrapper => wrapper.findAll('.select');
const confirmar = wrapper => wrapper.find('.confirmar');
const avisos = wrapper => wrapper.findAll('.erro-campo');

const preencherTexto = async wrapper => {
  await wrapper.find('input.campo').setValue('Não emite nota');
  await wrapper.find('textarea.campo').setValue('Detalhes do problema');
};

const botaoDeTexto = (wrapper, texto) =>
  wrapper.findAll('button').find(b => b.text() === texto);

beforeEach(() => {
  createTicket.mockClear();
  aiDraftEnabled.mockClear();
  generateTicketDraft.mockClear();
  useAlert.mockClear();
});

describe('ClientTicketDialog', () => {
  // O botão NÃO fica desabilitado: um botão apagado não diz o que falta, e a
  // pessoa fica olhando para a tela sem saber o que fazer. O clique é que
  // aponta o campo.
  it('names what is missing instead of sending', async () => {
    const wrapper = montar();

    await confirmar(wrapper).trigger('click');

    expect(createTicket).not.toHaveBeenCalled();
    // Categoria, Assunto e Descrição - os três que faltam.
    expect(avisos(wrapper)).toHaveLength(3);
  });

  // A borda diz ONDE; a mensagem diz O QUÊ. Um sem o outro deixa a pessoa
  // procurando.
  it('marks the field itself, not only the text', async () => {
    const wrapper = montar();

    await confirmar(wrapper).trigger('click');

    expect(selects(wrapper)[0].attributes('data-error')).toBe('true');
  });

  it('clears a field warning as soon as it is filled', async () => {
    const wrapper = montar();
    await confirmar(wrapper).trigger('click');
    expect(avisos(wrapper)).toHaveLength(3);

    await selects(wrapper)[0].find('[data-value="1"]').trigger('click');
    await preencherTexto(wrapper);

    expect(avisos(wrapper)).toHaveLength(0);
  });

  // A categoria pode exigir anexo; nesse caso o campo do arquivo é o marcado.
  it('points at the file field when the category demands one', async () => {
    const wrapper = montar();
    await selects(wrapper)[0].find('[data-value="2"]').trigger('click');
    await preencherTexto(wrapper);

    await confirmar(wrapper).trigger('click');

    expect(createTicket).not.toHaveBeenCalled();
    expect(avisos(wrapper)).toHaveLength(1);
    expect(avisos(wrapper)[0].text()).toContain(
      'CLIENT_AREA.NEW_TICKET.ERRORS.FILES'
    );
  });

  it('offers every category, without asking for a Mesa', async () => {
    const wrapper = montar();

    expect(selects(wrapper)).toHaveLength(1);
    expect(
      selects(wrapper)[0]
        .findAll('[data-value]')
        .map(n => n.text())
    ).toEqual(['Dúvida', 'Erro']);
  });

  // Mesa, Estágio e prioridade são decisão da triagem: não saem daqui.
  it('never sends a Mesa or a priority', async () => {
    const wrapper = montar();
    await selects(wrapper)[0].find('[data-value="1"]').trigger('click');
    await preencherTexto(wrapper);
    await confirmar(wrapper).trigger('click');

    const enviado = createTicket.mock.calls[0][0];
    expect(enviado).not.toHaveProperty('team_id');
    expect(enviado).not.toHaveProperty('priority');
  });

  // Empresa e solicitante não são escolha dele: nem sequer são enviados.
  it('never sends company or contact', async () => {
    const wrapper = montar();
    await selects(wrapper)[0].find('[data-value="1"]').trigger('click');
    await preencherTexto(wrapper);
    await confirmar(wrapper).trigger('click');
    await flushPromises();

    const enviado = createTicket.mock.calls[0][0];
    expect(Object.keys(enviado)).toEqual([
      'ticket_category_id',
      'title',
      'description',
    ]);
  });

  it('trims what was typed', async () => {
    const wrapper = montar();
    await selects(wrapper)[0].find('[data-value="1"]').trigger('click');
    await wrapper.find('input.campo').setValue('  Assunto  ');
    await wrapper.find('textarea.campo').setValue('  Descrição  ');
    await confirmar(wrapper).trigger('click');

    expect(createTicket).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Assunto', description: 'Descrição' }),
      []
    );
  });

  describe('abrir com IA', () => {
    // A consulta do servidor para o rascunho é a MESMA que monta a lista de
    // categorias - sem nenhuma, gerar sempre falharia com `no_categories`.
    // Oferecer o botão nesse estado seria oferecer algo que só sabe falhar.
    it('hides the AI option when there is no category to draft into', async () => {
      const wrapper = montar({ categories: [] });
      await wrapper.vm.open();
      await flushPromises();

      expect(
        botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.TOGGLE')
      ).toBeUndefined();
    });

    it('offers the AI option when a category exists and the credential is set', async () => {
      const wrapper = montar();
      await wrapper.vm.open();
      await flushPromises();

      expect(
        botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.TOGGLE')
      ).not.toBeUndefined();
    });

    it('stays hidden without a configured credential, even with categories available', async () => {
      aiDraftEnabled.mockResolvedValueOnce({ data: { enabled: false } });
      const wrapper = montar();
      await wrapper.vm.open();
      await flushPromises();

      expect(
        botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.TOGGLE')
      ).toBeUndefined();
    });

    const abrirPainelDeIa = async wrapper => {
      await wrapper.vm.open();
      await flushPromises();
      await botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.TOGGLE').trigger(
        'click'
      );
    };

    // O servidor manda um CÓDIGO ('no_categories', 'empty_input'), nunca o
    // texto pronto - mostrar a palavra em inglês direto na tela seria o
    // defeito relatado. Cobre mesmo não sendo mais alcançável pelo botão (a
    // categoria pode ser removida por um administrador enquanto o diálogo já
    // está aberto em outra aba).
    it('translates no_categories instead of showing the raw code', async () => {
      generateTicketDraft.mockRejectedValueOnce({
        response: { data: { error: 'no_categories' } },
      });
      const wrapper = montar();
      await abrirPainelDeIa(wrapper);
      await wrapper.find('textarea.campo').setValue('Preciso de ajuda');
      await botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.GENERATE').trigger(
        'click'
      );
      await flushPromises();

      expect(useAlert).toHaveBeenCalledWith(
        'CLIENT_AREA.NEW_TICKET.AI.ERROR_NO_CATEGORIES'
      );
    });

    it('translates empty_input instead of showing the raw code', async () => {
      generateTicketDraft.mockRejectedValueOnce({
        response: { data: { error: 'empty_input' } },
      });
      const wrapper = montar();
      await abrirPainelDeIa(wrapper);
      await wrapper.find('textarea.campo').setValue('Preciso de ajuda');
      await botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.GENERATE').trigger(
        'click'
      );
      await flushPromises();

      expect(useAlert).toHaveBeenCalledWith(
        'CLIENT_AREA.NEW_TICKET.AI.ERROR_EMPTY_INPUT'
      );
    });

    // Um erro do PROVEDOR de IA é texto livre, sem tradução nossa - cai no
    // aviso genérico em vez de qualquer um dos dois códigos fixos.
    it('falls back to the generic message for anything else', async () => {
      generateTicketDraft.mockRejectedValueOnce({
        response: { data: { error: 'rate_limit_exceeded' } },
      });
      const wrapper = montar();
      await abrirPainelDeIa(wrapper);
      await wrapper.find('textarea.campo').setValue('Preciso de ajuda');
      await botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.GENERATE').trigger(
        'click'
      );
      await flushPromises();

      expect(useAlert).toHaveBeenCalledWith('CLIENT_AREA.NEW_TICKET.AI.ERROR');
    });

    it('fills the form from the generated draft', async () => {
      const wrapper = montar();
      await abrirPainelDeIa(wrapper);
      await wrapper.find('textarea.campo').setValue('Preciso de ajuda');
      await botaoDeTexto(wrapper, 'CLIENT_AREA.NEW_TICKET.AI.GENERATE').trigger(
        'click'
      );
      await flushPromises();
      await confirmar(wrapper).trigger('click');

      expect(createTicket).toHaveBeenCalledWith(
        expect.objectContaining({
          ticket_category_id: 1,
          title: 'Título',
          description: 'Descrição',
        }),
        []
      );
    });
  });
});
