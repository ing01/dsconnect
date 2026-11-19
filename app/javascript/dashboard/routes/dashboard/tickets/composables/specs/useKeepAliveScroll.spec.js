import { mount } from '@vue/test-utils';
import { defineComponent, h, KeepAlive, nextTick, ref } from 'vue';
import { useKeepAliveScroll } from '../useKeepAliveScroll';

const Page = defineComponent({
  name: 'ScrollPage',
  setup() {
    const root = ref(null);
    useKeepAliveScroll(root);
    return () =>
      h('div', { ref: root, 'data-testid': 'root' }, [
        h('div', { 'data-testid': 'inner' }),
      ]);
  },
});

const Other = defineComponent({ name: 'OtherPage', render: () => h('p') });

const nextFrame = () => new Promise(resolve => requestAnimationFrame(resolve));

const mountSwitcher = () => {
  const current = ref('ScrollPage');
  const wrapper = mount(
    {
      render: () =>
        h(KeepAlive, { include: ['ScrollPage'] }, () =>
          h(current.value === 'ScrollPage' ? Page : Other)
        ),
    },
    { attachTo: document.body }
  );
  return { wrapper, current };
};

describe('useKeepAliveScroll', () => {
  it('gives back the scroll of the page and of an inner element when it returns', async () => {
    const { wrapper, current } = mountSwitcher();
    const root = wrapper.find('[data-testid="root"]').element;
    const inner = wrapper.find('[data-testid="inner"]').element;

    root.scrollTop = 120;
    root.dispatchEvent(new Event('scroll'));
    inner.scrollLeft = 40;
    inner.dispatchEvent(new Event('scroll'));

    current.value = 'OtherPage';
    await nextTick();
    // O navegador zera a rolagem dos elementos que saem da pagina.
    root.scrollTop = 0;
    inner.scrollLeft = 0;

    current.value = 'ScrollPage';
    await nextTick();
    await nextFrame();

    expect(root.scrollTop).toBe(120);
    expect(inner.scrollLeft).toBe(40);
    wrapper.unmount();
  });

  it('does nothing when nothing was scrolled', async () => {
    const { wrapper, current } = mountSwitcher();
    const root = wrapper.find('[data-testid="root"]').element;

    current.value = 'OtherPage';
    await nextTick();
    current.value = 'ScrollPage';
    await nextTick();
    await nextFrame();

    expect(root.scrollTop).toBe(0);
    wrapper.unmount();
  });
});
