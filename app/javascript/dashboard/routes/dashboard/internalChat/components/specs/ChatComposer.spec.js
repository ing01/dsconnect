import { mount, flushPromises } from '@vue/test-utils';
import { DirectUpload } from 'activestorage';
import ChatComposer from '../ChatComposer.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/helper/directUploadsHelper', () => ({
  setDirectUploadAuthHeaders: vi.fn(),
}));
vi.mock('activestorage');

const montar = () =>
  mount(ChatComposer, {
    props: { channelId: 1 },
    global: {
      stubs: {
        OnClickOutside: { template: '<div><slot /></div>' },
        Icon: true,
        Button: {
          props: ['label', 'disabled'],
          emits: ['click'],
          template:
            '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const textarea = wrapper => wrapper.find('textarea');

describe('ChatComposer', () => {
  beforeEach(() => {
    DirectUpload.mockReset();
    // jsdom nao implementa isso - so' usado aqui pra pre-visualizar a
    // imagem colada antes do upload terminar, sem ida ao servidor.
    global.URL.createObjectURL = vi.fn(() => 'blob:preview');
    global.URL.revokeObjectURL = vi.fn();
  });

  it('Enter envia a mensagem e limpa o campo', async () => {
    const wrapper = montar();
    await textarea(wrapper).setValue('oi pessoal');

    await textarea(wrapper).trigger('keydown', { key: 'Enter' });

    expect(wrapper.emitted('send')[0][0]).toMatchObject({
      body: 'oi pessoal',
      attachments: [],
    });
    expect(wrapper.vm.body).toBe('');
  });

  it('Shift+Enter nao envia', async () => {
    const wrapper = montar();
    await textarea(wrapper).setValue('linha 1');

    await textarea(wrapper).trigger('keydown', {
      key: 'Enter',
      shiftKey: true,
    });

    expect(wrapper.emitted('send')).toBeUndefined();
  });

  // Ctrl+Enter quebra a linha no ponto do cursor E ja envia com ela - numa
  // tecla so, sem o `.trim()` apagar a quebra quando ela cai no fim do texto.
  it('Ctrl+Enter quebra linha no cursor e envia junto, sem perder a quebra no trim', async () => {
    const wrapper = montar();
    const field = textarea(wrapper).element;
    await textarea(wrapper).setValue('primeira linha');
    field.setSelectionRange(field.value.length, field.value.length);

    await textarea(wrapper).trigger('keydown', {
      key: 'Enter',
      ctrlKey: true,
    });

    expect(wrapper.emitted('send')[0][0].body).toBe('primeira linha\n');
  });

  it('Cmd+Enter (metaKey) se comporta igual ao Ctrl+Enter', async () => {
    const wrapper = montar();
    const field = textarea(wrapper).element;
    await textarea(wrapper).setValue('abc');
    field.setSelectionRange(1, 1);

    await textarea(wrapper).trigger('keydown', {
      key: 'Enter',
      metaKey: true,
    });

    expect(wrapper.emitted('send')[0][0].body).toBe('a\nbc');
  });

  it('nao envia com Ctrl+Enter se o campo esta vazio', async () => {
    const wrapper = montar();

    await textarea(wrapper).trigger('keydown', {
      key: 'Enter',
      ctrlKey: true,
    });

    expect(wrapper.emitted('send')).toBeUndefined();
  });

  it('colar uma imagem sobe o arquivo e vira anexo pendente', async () => {
    DirectUpload.mockImplementation(() => ({
      create: callback => callback(null, { signed_id: 'blob-123' }),
    }));
    const wrapper = montar();
    const file = new File(['conteudo'], 'print.png', { type: 'image/png' });

    await textarea(wrapper).trigger('paste', {
      clipboardData: { files: [file] },
    });
    await flushPromises();

    expect(DirectUpload).toHaveBeenCalled();
    expect(wrapper.vm.pendingAttachments).toHaveLength(1);
    expect(wrapper.vm.pendingAttachments[0]).toMatchObject({
      signedId: 'blob-123',
      name: 'print.png',
      kind: 'image',
    });
  });

  it('colar texto comum (sem arquivo) nao interfere no upload', async () => {
    const wrapper = montar();

    await textarea(wrapper).trigger('paste', { clipboardData: { files: [] } });
    await flushPromises();

    expect(DirectUpload).not.toHaveBeenCalled();
  });
});
