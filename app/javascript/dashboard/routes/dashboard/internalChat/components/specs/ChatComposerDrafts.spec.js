import { mount, flushPromises } from '@vue/test-utils';
import { DirectUpload } from 'activestorage';
import ChatComposer from '../ChatComposer.vue';
import ChatSidebar from '../ChatSidebar.vue';
import { reloadDrafts, writeDraft } from 'dashboard/helper/textDrafts';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/helper/directUploadsHelper', () => ({
  setDirectUploadAuthHeaders: vi.fn(),
}));
vi.mock('activestorage');

const $store = { getters: { getCurrentAccountId: 1, getCurrentUserID: 9 } };
const loja = {
  install: app => {
    app.config.globalProperties.$store = $store;
  },
};

const montar = (channelId = 1) =>
  mount(ChatComposer, {
    props: { channelId },
    global: {
      plugins: [loja],
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Icon: true,
        Button: {
          props: ['label', 'disabled'],
          emits: ['click'],
          template:
            '<button class="enviar" :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const campo = wrapper => wrapper.find('textarea');
const texto = wrapper => campo(wrapper).element.value;
const sala = (wrapper, channelId) => wrapper.setProps({ channelId });
const enter = wrapper => campo(wrapper).trigger('keydown', { key: 'Enter' });
const enviado = (wrapper, index = 0) => wrapper.emitted('send')[index][0];
const aviso = '[data-testid="draft-notice"]';
const imagem = () => new File(['x'], 'print.png', { type: 'image/png' });
const colar = async wrapper => {
  await campo(wrapper).trigger('paste', {
    clipboardData: { files: [imagem()] },
  });
  await flushPromises();
};
const anexos = wrapper => wrapper.vm.pendingAttachments.map(a => a.signedId);

describe('ChatComposer - rascunhos', () => {
  beforeEach(() => {
    localStorage.clear();
    reloadDrafts();
    let upload = 0;
    DirectUpload.mockReset();
    DirectUpload.mockImplementation(() => ({
      create: callback => {
        upload += 1;
        callback(null, { signed_id: `blob-${upload}` });
      },
    }));
    global.URL.createObjectURL = vi.fn(() => 'blob:preview');
    global.URL.revokeObjectURL = vi.fn();
  });

  it('o texto de uma conversa nao aparece em outra', async () => {
    const wrapper = montar(1);
    await campo(wrapper).setValue('so para a Maria');

    await sala(wrapper, 2);
    expect(texto(wrapper)).toBe('');
    await enter(wrapper);
    expect(wrapper.emitted('send')).toBeUndefined();

    await sala(wrapper, 1);
    expect(texto(wrapper)).toBe('so para a Maria');
  });

  it('volta o texto depois de sair da tela, com a opcao de descartar', async () => {
    const first = montar(1);
    await campo(first).setValue('depois eu termino');
    expect(first.find(aviso).exists()).toBe(false);
    first.unmount();
    reloadDrafts();

    const wrapper = montar(1);
    expect(texto(wrapper)).toBe('depois eu termino');
    expect(wrapper.find(aviso).exists()).toBe(true);

    await wrapper.find('[data-testid="draft-discard"]').trigger('click');
    expect(texto(wrapper)).toBe('');
    expect(wrapper.find(aviso).exists()).toBe(false);
  });

  it('enviado com sucesso, nao volta', async () => {
    const wrapper = montar(1);
    await campo(wrapper).setValue('oi');
    await enter(wrapper);

    enviado(wrapper).onSettled(true);

    expect(texto(wrapper)).toBe('');
    expect(texto(montar(1))).toBe('');
  });

  it('se o envio falhar, texto e anexos voltam', async () => {
    const wrapper = montar(1);
    await colar(wrapper);
    await campo(wrapper).setValue('segue o print');
    await enter(wrapper);
    expect(texto(wrapper)).toBe('');
    expect(anexos(wrapper)).toEqual([]);

    enviado(wrapper).onSettled(false);
    await flushPromises();

    expect(texto(wrapper)).toBe('segue o print');
    expect(anexos(wrapper)).toEqual(['blob-1']);
    expect(global.URL.revokeObjectURL).not.toHaveBeenCalled();

    await enter(wrapper);
    expect(enviado(wrapper, 1)).toMatchObject({
      body: 'segue o print',
      attachments: ['blob-1'],
    });
    enviado(wrapper, 1).onSettled(true);
    expect(global.URL.revokeObjectURL).toHaveBeenCalledTimes(1);
  });

  it('falhando depois da troca de sala, volta so na sala de origem', async () => {
    const wrapper = montar(1);
    await campo(wrapper).setValue('para a sala 1');
    await enter(wrapper);
    await sala(wrapper, 2);
    await campo(wrapper).setValue('na sala 2');

    enviado(wrapper).onSettled(false);
    await flushPromises();

    expect(texto(wrapper)).toBe('na sala 2');
    await sala(wrapper, 1);
    expect(texto(wrapper)).toBe('para a sala 1');
  });

  it('falhando depois de sair da tela, o texto fica no rascunho', async () => {
    const wrapper = montar(1);
    await campo(wrapper).setValue('nao se perca');
    await enter(wrapper);
    const { onSettled } = enviado(wrapper);
    wrapper.unmount();

    onSettled(false);

    expect(texto(montar(1))).toBe('nao se perca');
  });

  it('o botao Enviar e o Ctrl+Enter tambem devolvem o texto', async () => {
    const wrapper = montar(1);
    await campo(wrapper).setValue('pelo botao');
    await wrapper.find('button.enviar').trigger('click');
    enviado(wrapper).onSettled(false);
    await flushPromises();
    expect(texto(wrapper)).toBe('pelo botao');

    await campo(wrapper).trigger('keydown', { key: 'Enter', ctrlKey: true });
    enviado(wrapper, 1).onSettled(false);
    await flushPromises();
    expect(texto(wrapper)).toBe(enviado(wrapper, 1).body);
  });

  it('os anexos ficam na conversa onde foram colocados', async () => {
    const wrapper = montar(1);
    await colar(wrapper);

    await sala(wrapper, 2);
    expect(anexos(wrapper)).toEqual([]);
    expect(wrapper.find('button.enviar').element.disabled).toBe(true);

    await sala(wrapper, 1);
    expect(anexos(wrapper)).toEqual(['blob-1']);
  });

  it('upload que termina depois da troca continua na sala de origem', async () => {
    let finish;
    DirectUpload.mockImplementation(() => ({
      create: callback => {
        finish = () => callback(null, { signed_id: 'lento' });
      },
    }));
    const wrapper = montar(1);
    await colar(wrapper);
    await sala(wrapper, 2);

    // A outra sala nao fica travada pelo envio de arquivo desta.
    await campo(wrapper).setValue('posso enviar');
    expect(wrapper.find('button.enviar').element.disabled).toBe(false);

    finish();
    await flushPromises();
    expect(anexos(wrapper)).toEqual([]);

    await sala(wrapper, 1);
    expect(anexos(wrapper)).toEqual(['lento']);
  });

  it('remover um anexo vale so para a sala atual', async () => {
    const wrapper = montar(1);
    await colar(wrapper);
    await colar(wrapper);
    await wrapper
      .find('[title="INTERNAL_CHAT.COMPOSER.REMOVE_ATTACHMENT"]')
      .trigger('click');

    expect(anexos(wrapper)).toEqual(['blob-2']);
    expect(global.URL.revokeObjectURL).toHaveBeenCalledTimes(1);
  });
});

describe('ChatSidebar - marca de rascunho', () => {
  const rooms = {
    channels: [{ id: 7, kind: 'channel', name: 'suporte', messages: [] }],
    directs: [{ id: 5, kind: 'direct', userId: 12, messages: [] }],
    users: [{ id: 12, name: 'Maria Silva' }],
  };
  const barra = (activeRoomId = null) =>
    mount(ChatSidebar, {
      props: { ...rooms, activeRoomId },
      global: {
        plugins: [loja],
        stubs: {
          Icon: { template: '<i />' },
          Avatar: true,
          OnClickOutside: true,
        },
      },
    });
  const marcas = wrapper => wrapper.findAll('[data-testid="room-draft"]');

  beforeEach(() => {
    localStorage.clear();
    reloadDrafts();
  });

  it('sem rascunho nao marca nada', () => {
    expect(marcas(barra())).toHaveLength(0);
  });

  it('marca canal e conversa privada com texto por enviar', async () => {
    const wrapper = barra();

    writeDraft('1:9:chat:7', 'aviso');
    writeDraft('1:9:chat:5', 'oi Maria');
    await flushPromises();

    expect(marcas(wrapper)).toHaveLength(2);
    expect(wrapper.text()).toContain('oi Maria');
  });

  it('a conversa aberta nao leva a marca, nem texto so de espacos', () => {
    writeDraft('1:9:chat:5', 'aberta');
    writeDraft('1:9:chat:7', '   ');

    expect(marcas(barra(5))).toHaveLength(0);
  });
});
