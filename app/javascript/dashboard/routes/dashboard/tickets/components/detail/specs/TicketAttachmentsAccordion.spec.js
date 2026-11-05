import { mount, flushPromises } from '@vue/test-utils';
import TicketAttachmentsAccordion from '../TicketAttachmentsAccordion.vue';

const useAlert = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => useAlert(...args),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const downloadFile = vi.fn(() => Promise.resolve());
vi.mock('@chatwoot/utils', () => ({
  downloadFile: (...args) => downloadFile(...args),
}));

const downloadBlob = vi.fn();
vi.mock('dashboard/helper/downloadHelper', () => ({
  downloadBlob: (...args) => downloadBlob(...args),
}));

const downloadAllAttachments = vi.fn(() =>
  Promise.resolve({ data: new Blob(['zip']), headers: {} })
);
vi.mock('dashboard/api/tickets', () => ({
  default: {
    downloadAllAttachments: (...args) => downloadAllAttachments(...args),
  },
}));

let attachments = [];
const dispatch = vi.fn(() => Promise.resolve());
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await import('vue');
  return {
    useStore: () => ({
      getters: {
        'tickets/getAttachments': () => attachments,
      },
      dispatch: (...args) => dispatch(...args),
    }),
    useMapGetter: () => computed(() => ({})),
  };
});

const previewOpen = vi.fn();

const montar = (props = {}) =>
  mount(TicketAttachmentsAccordion, {
    props: { ticketId: 1, ...props },
    global: {
      stubs: {
        Accordion: { props: ['title'], template: '<div><slot /></div>' },
        Icon: true,
        Spinner: true,
        TicketAttachmentPreviewDialog: {
          template: '<div />',
          methods: { open: (...args) => previewOpen(...args), close: () => {} },
        },
        Button: {
          props: ['label', 'ariaLabel', 'isLoading'],
          emits: ['click'],
          template:
            '<button :aria-label="ariaLabel" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const imagem = (overrides = {}) => ({
  id: 1,
  filename: 'foto.png',
  content_type: 'image/png',
  byte_size: 1024,
  file_url: 'https://example.com/foto.png',
  ...overrides,
});

const planilha = (overrides = {}) => ({
  id: 2,
  filename: 'planilha.xlsx',
  content_type:
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  byte_size: 2048,
  file_url: 'https://example.com/planilha.xlsx',
  ...overrides,
});

describe('TicketAttachmentsAccordion', () => {
  beforeEach(() => {
    attachments = [];
    downloadFile.mockClear();
    downloadBlob.mockClear();
    downloadAllAttachments.mockClear();
    useAlert.mockClear();
    previewOpen.mockClear();
  });

  it('abre a pre-visualizacao ao clicar num anexo de imagem', async () => {
    attachments = [imagem()];
    const wrapper = montar();

    await wrapper.find('button[title="foto.png"]').trigger('click');

    expect(previewOpen).toHaveBeenCalledWith(attachments[0]);
  });

  it('abre em nova aba (nao pre-visualiza) um anexo que nao e imagem', async () => {
    attachments = [planilha()];
    const openSpy = vi.spyOn(window, 'open').mockImplementation(() => {});
    const wrapper = montar();

    await wrapper.find('button[title="planilha.xlsx"]').trigger('click');

    expect(openSpy).toHaveBeenCalledWith(
      planilha().file_url,
      '_blank',
      'noopener,noreferrer'
    );
    expect(previewOpen).not.toHaveBeenCalled();
    openSpy.mockRestore();
  });

  it('baixa um unico arquivo pelo botao de download', async () => {
    attachments = [imagem()];
    const wrapper = montar();

    await wrapper
      .find('[aria-label="TICKET.DETAIL.ATTACHMENTS.DOWNLOAD"]')
      .trigger('click');
    await flushPromises();

    expect(downloadFile).toHaveBeenCalledWith({
      url: imagem().file_url,
      type: 'image',
      extension: 'png',
    });
  });

  it('mostra erro quando o download de um arquivo falha', async () => {
    downloadFile.mockRejectedValueOnce(new Error('falhou'));
    attachments = [imagem()];
    const wrapper = montar();

    await wrapper
      .find('[aria-label="TICKET.DETAIL.ATTACHMENTS.DOWNLOAD"]')
      .trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ERROR'
    );
  });

  it('nao mostra "baixar todos" com 0 ou 1 anexo', () => {
    attachments = [imagem()];
    const wrapper = montar();

    expect(wrapper.text()).not.toContain(
      'TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL'
    );
  });

  it('baixa todos como .zip quando ha mais de um anexo', async () => {
    attachments = [imagem(), planilha()];
    const wrapper = montar();

    await wrapper
      .findAll('button')
      .find(b => b.text() === 'TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL')
      .trigger('click');
    await flushPromises();

    expect(downloadAllAttachments).toHaveBeenCalledWith(1);
    expect(downloadBlob).toHaveBeenCalled();
  });

  it('mostra erro quando "baixar todos" falha', async () => {
    downloadAllAttachments.mockRejectedValueOnce(new Error('falhou'));
    attachments = [imagem(), planilha()];
    const wrapper = montar();

    await wrapper
      .findAll('button')
      .find(b => b.text() === 'TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL')
      .trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'TICKET.DETAIL.ATTACHMENTS.DOWNLOAD_ALL_ERROR'
    );
  });

  it('esconde o botao de excluir sem permissao de atualizar', () => {
    attachments = [imagem()];
    const wrapper = montar({ canUpdate: false });

    expect(
      wrapper.find('[aria-label="TICKET.DETAIL.ATTACHMENTS.DELETE"]').exists()
    ).toBe(false);
    expect(
      wrapper.find('[aria-label="TICKET.DETAIL.ATTACHMENTS.DOWNLOAD"]').exists()
    ).toBe(true);
  });
});
