import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import ArticleTreeBoard from '../ArticleTreeBoard.vue';
import articlesAPI from 'dashboard/api/helpCenter/articles';

const { routeState, routerMock } = vi.hoisted(() => ({
  routeState: { query: {}, params: {} },
  routerMock: { replace: vi.fn(), push: vi.fn() },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => routeState,
  useRouter: () => routerMock,
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/helpCenter/articles', () => ({
  default: {
    getTree: vi.fn(),
    getArticle: vi.fn(),
    getArticles: vi.fn(),
    moveArticle: vi.fn(),
  },
}));
vi.mock('dashboard/api/forms', () => ({
  default: { show: vi.fn(), get: vi.fn(), fillResponse: vi.fn() },
}));
vi.mock('dashboard/api/helpCenter/categories', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/helper/commons', () => ({
  convertToCategorySlug: text => text.toLowerCase(),
}));

const TREE = {
  categories: [
    {
      id: 1,
      name: 'Processos',
      slug: 'processos',
      position: 10,
      parent_category_id: null,
    },
    {
      id: 2,
      name: 'Sistemas',
      slug: 'sistemas',
      position: 20,
      parent_category_id: null,
    },
  ],
  articles: [
    {
      id: 11,
      title: 'POP 1',
      status: 'published',
      position: 10,
      category_id: 1,
      parent_article_id: null,
    },
    {
      id: 12,
      title: 'POP 1.1',
      status: 'published',
      position: 10,
      category_id: 1,
      parent_article_id: 11,
    },
    {
      id: 14,
      title: 'POP 2',
      status: 'draft',
      position: 20,
      category_id: 1,
      parent_article_id: null,
    },
  ],
};

const detail = (id, extra = {}) => ({
  data: {
    payload: {
      id,
      title: id === 11 ? 'POP 1' : 'POP 1.1',
      status: 'published',
      views: 3,
      updated_at: 1700000000,
      rendered_content:
        '<p>Veja <a href="/dsref/article/14" data-ref-type="article" data-ref-id="14">POP 2</a></p>',
      ancestors: [],
      forms: [
        {
          id: 7,
          name: 'Abertura',
          fields: [{ id: 'f1', label: 'Motivo', field_type: 'short_text' }],
        },
      ],
      meta: { tags: ['POP'] },
      author: { name: 'Ana' },
      ...extra,
    },
  },
});

// Os dialogos e o menu usam Teleport/dialog nativo; aqui so' interessa a tela.
const stubs = {
  Dialog: {
    template: '<div><slot /></div>',
    methods: { open() {}, close() {} },
  },
};

const mountBoard = async (props = {}) => {
  articlesAPI.getTree.mockResolvedValue({ data: TREE });
  articlesAPI.getArticle.mockImplementation(({ id }) =>
    Promise.resolve(detail(id))
  );
  const wrapper = mount(ArticleTreeBoard, {
    props: { portalSlug: 'base', locale: 'pt_BR', canManage: true, ...props },
    global: { stubs },
  });
  await flushPromises();
  return wrapper;
};

describe('ArticleTreeBoard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    routeState.query = reactive({});
    routerMock.replace.mockImplementation(({ query }) => {
      routeState.query = reactive({ ...query });
    });
  });

  it('loads the tree of the language and shows the folders opened', async () => {
    const wrapper = await mountBoard();

    expect(articlesAPI.getTree).toHaveBeenCalledWith({
      portalSlug: 'base',
      locale: 'pt_BR',
    });
    const tree = wrapper.find('[data-testid="kb-tree"]');
    expect(tree.text()).toContain('Processos');
    expect(tree.text()).toContain('POP 1');
    expect(tree.text()).toContain('POP 2');
  });

  it('shows the hint while no article is chosen', async () => {
    const wrapper = await mountBoard();

    expect(wrapper.find('[data-testid="kb-viewer-empty"]').exists()).toBe(true);
  });

  it('opens the article in the center and keeps the tree', async () => {
    routeState.query = reactive({ article: '11' });
    const wrapper = await mountBoard();

    expect(articlesAPI.getArticle).toHaveBeenCalledWith({
      id: 11,
      portalSlug: 'base',
    });
    expect(wrapper.find('[data-testid="kb-viewer"]').text()).toContain('POP 1');
    expect(wrapper.find('[data-testid="kb-tree"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="kb-details"]').text()).toContain(
      'Processos'
    );
  });

  it('shows the sub-articles in the structure and the linked forms', async () => {
    routeState.query = reactive({ article: '11' });
    const wrapper = await mountBoard();

    expect(wrapper.find('[data-testid="kb-structure"]').text()).toContain(
      'POP 1.1'
    );
    expect(wrapper.find('[data-testid="kb-forms"]').text()).toContain(
      'Abertura'
    );
    expect(wrapper.find('[data-testid="kb-form-fill-7"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="kb-form-consult-7"]').exists()).toBe(
      true
    );
  });

  it('follows a reference inside the content to the other article', async () => {
    routeState.query = reactive({ article: '11' });
    const wrapper = await mountBoard();

    await wrapper.find('[data-testid="kb-content"] a').trigger('click');

    expect(routerMock.replace).toHaveBeenCalledWith({ query: { article: 14 } });
  });

  it('puts the chosen article in the address', async () => {
    const wrapper = await mountBoard();

    const items = wrapper.findAll('[role="treeitem"]');
    await items.find(item => item.text().includes('POP 2')).trigger('click');

    expect(routerMock.replace).toHaveBeenCalledWith({ query: { article: 14 } });
  });

  it('moves an article by dropping it on another article', async () => {
    articlesAPI.moveArticle.mockResolvedValue({ data: {} });
    const wrapper = await mountBoard();

    const items = wrapper.findAll('[role="treeitem"]');
    const source = items.find(item => item.text().startsWith('POP 2'));
    const target = items.find(
      item =>
        item.text().startsWith('POP 1') && !item.text().includes('POP 1.1')
    );
    const dataTransfer = { setData: vi.fn(), effectAllowed: '' };
    await source.trigger('dragstart', { dataTransfer });
    await target.trigger('dragover', { dataTransfer });
    await target.trigger('drop', { dataTransfer });
    await flushPromises();

    expect(articlesAPI.moveArticle).toHaveBeenCalledWith({
      portalSlug: 'base',
      articleId: 14,
      parentArticleId: 11,
      categoryId: null,
      index: undefined,
    });
    // recarrega a arvore para mostrar o novo lugar
    expect(articlesAPI.getTree).toHaveBeenCalledTimes(2);
  });

  it('does not offer drag, nor the management buttons, to who cannot manage', async () => {
    const wrapper = await mountBoard({ canManage: false });

    expect(wrapper.find('[data-testid="kb-new-article"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="kb-new-folder"]').exists()).toBe(false);
    expect(wrapper.find('[role="treeitem"][draggable="true"]').exists()).toBe(
      false
    );
  });

  it('collapses and expands a folder', async () => {
    const wrapper = await mountBoard();

    const folder = () =>
      wrapper
        .findAll('[role="treeitem"]')
        .find(item => item.text().startsWith('Processos'));
    await folder().trigger('click');
    expect(wrapper.find('[data-testid="kb-tree"]').text()).not.toContain(
      'POP 2'
    );

    await folder().trigger('click');
    expect(wrapper.find('[data-testid="kb-tree"]').text()).toContain('POP 2');
  });

  it('searches independently of the position, with the existing search', async () => {
    vi.useFakeTimers();
    articlesAPI.getArticles.mockResolvedValue({
      data: {
        payload: [
          { id: 12, title: 'POP 1.1', category: { name: 'Processos' } },
        ],
      },
    });
    const wrapper = await mountBoard();

    await wrapper.find('input[type="search"]').setValue('abertura');
    await vi.advanceTimersByTimeAsync(500);
    await flushPromises();
    vi.useRealTimers();

    expect(articlesAPI.getArticles).toHaveBeenCalledWith(
      expect.objectContaining({
        portalSlug: 'base',
        locale: 'pt_BR',
        query: 'abertura',
      })
    );
    expect(wrapper.find('[data-testid="kb-search-results"]').text()).toContain(
      'POP 1.1'
    );
    expect(wrapper.find('[data-testid="kb-tree"]').exists()).toBe(false);
  });

  it('goes to the new article screen with the parent, for a sub-article', async () => {
    routeState.query = reactive({ article: '11' });
    const wrapper = await mountBoard();

    await wrapper.find('[data-testid="kb-new-child"]').trigger('click');

    expect(routerMock.push).toHaveBeenCalledWith({
      name: 'portals_articles_new',
      params: { portalSlug: 'base', locale: 'pt_BR' },
      query: { parent: 11 },
    });
  });
});
