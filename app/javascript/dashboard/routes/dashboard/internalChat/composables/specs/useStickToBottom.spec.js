import { mount } from '@vue/test-utils';
import { defineComponent, h, nextTick, ref } from 'vue';
import { useStickToBottom, STICK_THRESHOLD_PX } from '../useStickToBottom';

// O jsdom nao tem layout: o teste define as medidas do elemento a mao e dispara o ResizeObserver
// que o composable cria, para provar a regra (acompanha, para de acompanhar, volta a acompanhar).
let observerCallback = null;
function FakeResizeObserver(callback) {
  observerCallback = callback;
  this.observe = () => {};
  this.disconnect = () => {};
}

const Page = defineComponent({
  setup(_, { expose }) {
    const scroller = ref(null);
    const content = ref(null);
    const api = useStickToBottom(scroller, content);
    expose(api);
    return () =>
      h('div', { ref: scroller }, [h('div', { ref: content }, 'conteudo')]);
  },
});

const measures = (element, { scrollHeight, clientHeight }) => {
  Object.defineProperty(element, 'scrollHeight', {
    value: scrollHeight,
    configurable: true,
  });
  Object.defineProperty(element, 'clientHeight', {
    value: clientHeight,
    configurable: true,
  });
};

describe('useStickToBottom', () => {
  beforeEach(() => {
    observerCallback = null;
    vi.stubGlobal('ResizeObserver', FakeResizeObserver);
  });

  afterEach(() => vi.unstubAllGlobals());

  const mountPage = async () => {
    const wrapper = mount(Page, { attachTo: document.body });
    await nextTick();
    const element = wrapper.element;
    measures(element, { scrollHeight: 1000, clientHeight: 400 });
    return { wrapper, element };
  };

  it('goes to the last message when told to follow', async () => {
    const { wrapper, element } = await mountPage();

    wrapper.vm.follow();

    expect(element.scrollTop).toBe(1000);
    wrapper.unmount();
  });

  it('keeps following when the content grows (new message, image loaded)', async () => {
    const { wrapper, element } = await mountPage();
    wrapper.vm.follow();

    measures(element, { scrollHeight: 1300, clientHeight: 400 });
    observerCallback();

    expect(element.scrollTop).toBe(1300);
    wrapper.unmount();
  });

  it('stops following when the person scrolls up to read, and does not pull them back', async () => {
    const { wrapper, element } = await mountPage();
    wrapper.vm.follow();

    element.scrollTop = 200; // longe do fim
    element.dispatchEvent(new Event('scroll'));
    measures(element, { scrollHeight: 1300, clientHeight: 400 });
    observerCallback();

    expect(wrapper.vm.isFollowing()).toBe(false);
    expect(element.scrollTop).toBe(200);
    wrapper.unmount();
  });

  it('follows again once the person gets back to the end', async () => {
    const { wrapper, element } = await mountPage();
    wrapper.vm.follow();
    element.scrollTop = 200;
    element.dispatchEvent(new Event('scroll'));

    element.scrollTop = 1000 - 400 - (STICK_THRESHOLD_PX - 10); // quase no fim
    element.dispatchEvent(new Event('scroll'));
    measures(element, { scrollHeight: 1300, clientHeight: 400 });
    observerCallback();

    expect(wrapper.vm.isFollowing()).toBe(true);
    expect(element.scrollTop).toBe(1300);
    wrapper.unmount();
  });
});
