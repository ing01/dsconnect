import { ref } from 'vue';
import { mount } from '@vue/test-utils';

import UnreadTabAlert from '../UnreadTabAlert.vue';

// Titulo da aba e favicon do navegador com o aviso, e a busca que mantem o aviso das
// conversas em dia.
const any = ref(false);
const dispatch = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: (...args) => dispatch(...args) }),
}));
vi.mock('dashboard/composables/useUnreadAlerts', () => ({
  useUnreadAlerts: () => ({ any }),
}));

const montar = () => mount(UnreadTabAlert);

describe('UnreadTabAlert', () => {
  beforeEach(() => {
    any.value = false;
    dispatch.mockReset();
    document.title = 'DSConnect';
    document.head.innerHTML =
      '<title>DSConnect</title>' +
      '<link class="favicon" rel="icon" sizes="32x32" href="/favicon-32x32.png">' +
      '<link class="favicon" rel="icon" sizes="16x16" href="/favicon-16x16.png">' +
      '<link class="favicon" rel="icon" sizes="512x512" href="/favicon-512x512.png">';
  });

  it('busca o aviso das conversas ao abrir', () => {
    montar().unmount();

    expect(dispatch).toHaveBeenCalledWith('unreadAssigned/fetch');
  });

  it('confere o aviso a cada minuto, so com a aba visivel (rede de seguranca)', () => {
    vi.useFakeTimers();
    const wrapper = montar();
    dispatch.mockClear();

    vi.advanceTimersByTime(60000);
    expect(dispatch).toHaveBeenCalledWith('unreadAssigned/fetch');

    dispatch.mockClear();
    Object.defineProperty(document, 'visibilityState', {
      value: 'hidden',
      configurable: true,
    });
    vi.advanceTimersByTime(60000);
    expect(dispatch).not.toHaveBeenCalledWith('unreadAssigned/fetch');

    Object.defineProperty(document, 'visibilityState', {
      value: 'visible',
      configurable: true,
    });
    wrapper.unmount();
    vi.useRealTimers();
  });

  it('sem aviso, o titulo e o favicon ficam como estao', () => {
    const wrapper = montar();

    expect(document.title).toBe('DSConnect');
    expect(
      document.querySelector('link[sizes="32x32"]').getAttribute('href')
    ).toBe('/favicon-32x32.png');
    wrapper.unmount();
  });

  it('com aviso, poe "(!)" no titulo e o selo no favicon', async () => {
    const wrapper = montar();

    any.value = true;
    await wrapper.vm.$nextTick();

    expect(document.title).toBe('(!) DSConnect');
    expect(
      document.querySelector('link[sizes="32x32"]').getAttribute('href')
    ).toBe('/favicon-badge-32x32.png');
    expect(
      document.querySelector('link[sizes="16x16"]').getAttribute('href')
    ).toBe('/favicon-badge-16x16.png');
    wrapper.unmount();
  });

  it('nao mexe no favicon de um tamanho que nao tem selo', async () => {
    const wrapper = montar();

    any.value = true;
    await wrapper.vm.$nextTick();

    expect(
      document.querySelector('link[sizes="512x512"]').getAttribute('href')
    ).toBe('/favicon-512x512.png');
    wrapper.unmount();
  });

  it('quando o aviso some, volta o titulo e o favicon normais', async () => {
    const wrapper = montar();
    any.value = true;
    await wrapper.vm.$nextTick();

    any.value = false;
    await wrapper.vm.$nextTick();

    expect(document.title).toBe('DSConnect');
    expect(
      document.querySelector('link[sizes="32x32"]').getAttribute('href')
    ).toBe('/favicon-32x32.png');
    wrapper.unmount();
  });

  it('se outra tela troca o titulo, o aviso volta junto', async () => {
    const wrapper = montar();
    any.value = true;
    await wrapper.vm.$nextTick();

    document.title = 'Tickets';
    await new Promise(resolve => {
      setTimeout(resolve, 0);
    });

    expect(document.title).toBe('(!) Tickets');
    wrapper.unmount();
  });

  it('ao sair, nao deixa o aviso preso no titulo', async () => {
    const wrapper = montar();
    any.value = true;
    await wrapper.vm.$nextTick();

    wrapper.unmount();

    expect(document.title).toBe('DSConnect');
    expect(dispatch).toHaveBeenCalledWith('unreadAssigned/clear');
  });
});
