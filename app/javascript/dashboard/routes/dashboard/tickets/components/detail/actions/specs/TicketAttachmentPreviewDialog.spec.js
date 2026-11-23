import { mount } from '@vue/test-utils';
import TicketAttachmentPreviewDialog from '../TicketAttachmentPreviewDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) =>
      params ? `${key} ${params.current}/${params.total}` : key,
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
// `useImageZoom` usa o debounce deste pacote, entao o mock mantem o resto como e'.
vi.mock('@chatwoot/utils', async importOriginal => ({
  ...(await importOriginal()),
  downloadFile: vi.fn(),
}));

const images = [
  { id: 1, filename: 'a.png', file_url: 'http://x/a.png' },
  { id: 2, filename: 'b.png', file_url: 'http://x/b.png' },
  { id: 3, filename: 'c.png', file_url: 'http://x/c.png' },
];

const mountDialog = () =>
  mount(TicketAttachmentPreviewDialog, {
    attachTo: document.body,
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open() {}, close() {} },
        },
      },
    },
  });

const pressKey = key =>
  document.dispatchEvent(new KeyboardEvent('keydown', { key }));

describe('TicketAttachmentPreviewDialog', () => {
  it('shows the picked image and a counter when the ticket has several', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(images[1], images);
    await wrapper.vm.$nextTick();

    expect(wrapper.find('img').attributes('src')).toBe('http://x/b.png');
    expect(wrapper.find('[data-testid="preview-counter"]').text()).toContain(
      '2/3'
    );
    wrapper.unmount();
  });

  it('moves with the arrow keys, wrapping around the ends', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(images[0], images);
    await wrapper.vm.$nextTick();

    pressKey('ArrowRight');
    await wrapper.vm.$nextTick();
    expect(wrapper.find('img').attributes('src')).toBe('http://x/b.png');

    pressKey('ArrowLeft');
    pressKey('ArrowLeft');
    await wrapper.vm.$nextTick();
    expect(wrapper.find('img').attributes('src')).toBe('http://x/c.png');
    wrapper.unmount();
  });

  it('moves with the side buttons', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(images[0], images);
    await wrapper.vm.$nextTick();

    await wrapper.find('[data-testid="preview-next"]').trigger('click');
    expect(wrapper.find('img').attributes('src')).toBe('http://x/b.png');

    await wrapper.find('[data-testid="preview-previous"]').trigger('click');
    expect(wrapper.find('img').attributes('src')).toBe('http://x/a.png');
    wrapper.unmount();
  });

  it('has no buttons, counter or key handling with a single image', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(images[0], [images[0]]);
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="preview-next"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="preview-counter"]').exists()).toBe(
      false
    );
    pressKey('ArrowRight');
    await wrapper.vm.$nextTick();
    expect(wrapper.find('img').attributes('src')).toBe('http://x/a.png');
    wrapper.unmount();
  });
});
