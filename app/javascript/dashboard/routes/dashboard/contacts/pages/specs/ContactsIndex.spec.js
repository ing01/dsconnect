import { mount, flushPromises } from '@vue/test-utils';
import { nextTick, reactive } from 'vue';
import ContactsIndex from '../ContactsIndex.vue';

// O campo de pesquisa nao pode ser reescrito pelo sistema enquanto a pessoa digita.
const route = reactive({
  name: 'contacts_dashboard_index',
  params: {},
  query: {},
});
// Como no navegador: a URL muda um instante depois do pedido.
const replace = vi.fn(({ query }) =>
  Promise.resolve().then(() => {
    route.query = query;
  })
);
let finishList;
const dispatch = vi.fn(action => {
  if (action !== 'contacts/get') return Promise.resolve();
  return new Promise(resolve => {
    finishList = resolve;
  });
});

vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ replace }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: (...args) => dispatch(...args) }),
  useMapGetter: getter => {
    const values = {
      'contacts/getUIFlags': {},
      'customViews/getUIFlags': {},
      'contacts/getMeta': {},
    };
    return { value: values[getter] || [] };
  },
}));
vi.mock('dashboard/api/bulkActions', () => ({ default: {} }));

const Layout = {
  name: 'ContactsListLayout',
  props: { searchValue: { type: String, default: '' } },
  emits: ['search'],
  template: '<div />',
};

const montar = () =>
  mount(ContactsIndex, {
    global: { stubs: { ContactsListLayout: Layout } },
  });

const searched = () =>
  dispatch.mock.calls
    .filter(([action]) => action === 'contacts/search')
    .map(([, payload]) => payload.search);

describe('ContactsIndex - campo de pesquisa', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    route.query = {};
    dispatch.mockClear();
  });
  afterEach(() => vi.useRealTimers());

  const digitar = async (wrapper, text) => {
    wrapper.findComponent(Layout).vm.$emit('search', text);
    await nextTick();
  };
  const campo = wrapper => wrapper.findComponent(Layout).props('searchValue');

  it('mostra o texto na hora, antes da busca', async () => {
    const wrapper = montar();

    await digitar(wrapper, 'ren');

    expect(campo(wrapper)).toBe('ren');
    expect(searched()).toEqual([]);
  });

  it('a URL da busca anterior nao apaga o que veio depois', async () => {
    const wrapper = montar();
    await digitar(wrapper, 'ren');
    await vi.advanceTimersByTimeAsync(400);
    await digitar(wrapper, 'renata');
    await flushPromises();

    expect(campo(wrapper)).toBe('renata');
    await vi.advanceTimersByTimeAsync(400);
    expect(campo(wrapper)).toBe('renata');
    expect(searched()).toEqual(['ren', 'renata']);
    expect(route.query.search).toBe('renata');
  });

  it('a lista que termina de carregar durante a digitacao nao limpa o campo', async () => {
    const wrapper = montar();
    await digitar(wrapper, 'cel');

    finishList();
    await flushPromises();
    await vi.advanceTimersByTimeAsync(400);

    expect(campo(wrapper)).toBe('cel');
    expect(route.query.search).toBe('cel');
  });

  it('segue a URL quando a mudanca vem de fora', async () => {
    const wrapper = montar();

    route.query = { search: 'rifane' };
    await nextTick();

    expect(campo(wrapper)).toBe('rifane');
  });
});
