import { mount, flushPromises } from '@vue/test-utils';
import SuggestionsPage from '../pages/SuggestionsPage.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions: () => true }),
}));

const { routerPush, routerReplace, routeRef } = vi.hoisted(() => ({
  routerPush: vi.fn(),
  routerReplace: vi.fn(),
  routeRef: { query: {}, params: { accountId: 1 } },
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: routerPush, replace: routerReplace }),
  useRoute: () => routeRef,
}));

const SUGESTOES = [
  { id: 1, title: 'Primeira sugestao' },
  { id: 42, title: 'Sugestao marcada na notificacao' },
];

const openSpy = vi.fn();

const dispatch = vi.fn(() => Promise.resolve());

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch,
    getters: {
      'suggestionColumns/getColumns': [],
      'suggestions/getSuggestions': SUGESTOES,
      'suggestions/getUIFlags': { isFetching: false },
      'suggestionPriorities/getItems': [],
      'suggestionCategories/getItems': [],
      'agents/getAgents': [],
    },
  }),
}));

const montar = () =>
  mount(SuggestionsPage, {
    global: {
      stubs: {
        SuggestionBoard: true,
        SuggestionCreateDialog: true,
        SuggestionDetailDialog: {
          template: '<div />',
          methods: { open: openSpy },
        },
      },
    },
  });

// O defeito: clicar na notificacao de uma sugestao nova levava a tela de
// Sugestoes vazia (ou nem isso) - quem recebeu o aviso tinha que procurar o
// card sozinho no quadro.
describe('SuggestionsPage', () => {
  beforeEach(() => {
    openSpy.mockClear();
    routerReplace.mockClear();
    routeRef.query = {};
  });

  it('opens the suggestion linked via `?suggestion=` once the board loads', async () => {
    routeRef.query = { suggestion: '42' };

    montar();
    await flushPromises();

    expect(openSpy).toHaveBeenCalledWith(SUGESTOES[1]);
  });

  it('removes the query param after opening it, so a refresh does not reopen it', async () => {
    routeRef.query = { suggestion: '42', other: 'kept' };

    montar();
    await flushPromises();

    expect(routerReplace).toHaveBeenCalledWith({ query: { other: 'kept' } });
  });

  it('does nothing when there is no suggestion query param', async () => {
    montar();
    await flushPromises();

    expect(openSpy).not.toHaveBeenCalled();
    expect(routerReplace).not.toHaveBeenCalled();
  });

  it('does nothing when the linked suggestion id no longer matches anything loaded', async () => {
    routeRef.query = { suggestion: '999' };

    montar();
    await flushPromises();

    expect(openSpy).not.toHaveBeenCalled();
  });
});
