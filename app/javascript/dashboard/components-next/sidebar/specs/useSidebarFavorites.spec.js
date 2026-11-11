import { ref } from 'vue';
import {
  orderMenuItems,
  useSidebarFavorites,
  FAVORITE_MENUS_KEY,
} from '../useSidebarFavorites';

const updateUISettings = vi.fn();
const uiSettings = ref({});

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));

const ITEMS = ['Principal', 'Inbox', 'Tickets', 'Agenda'].map(name => ({
  name,
}));
const names = list => list.map(item => item.name);

describe('orderMenuItems', () => {
  it('sem favoritos, devolve o menu como esta', () => {
    expect(orderMenuItems(ITEMS, [])).toBe(ITEMS);
  });

  it('poe os favoritos no inicio, na ordem em que foram favoritados', () => {
    expect(names(orderMenuItems(ITEMS, ['Agenda', 'Tickets']))).toEqual([
      'Agenda',
      'Tickets',
      'Principal',
      'Inbox',
    ]);
  });

  it('mantem o resto na ordem original', () => {
    expect(names(orderMenuItems(ITEMS, ['Inbox']))).toEqual([
      'Inbox',
      'Principal',
      'Tickets',
      'Agenda',
    ]);
  });

  it('ignora favorito que nao esta no menu (sem permissao, removido)', () => {
    expect(names(orderMenuItems(ITEMS, ['Fantasma', 'Tickets']))).toEqual([
      'Tickets',
      'Principal',
      'Inbox',
      'Agenda',
    ]);
  });

  it('nao duplica um favorito repetido e nao altera a lista original', () => {
    const resultado = orderMenuItems(ITEMS, ['Tickets', 'Tickets']);

    expect(resultado).toHaveLength(ITEMS.length);
    expect(names(ITEMS)).toEqual(['Principal', 'Inbox', 'Tickets', 'Agenda']);
  });

  it('nunca acrescenta um item que o menu nao montou', () => {
    expect(orderMenuItems(ITEMS, ['Settings'])).toHaveLength(ITEMS.length);
  });
});

describe('useSidebarFavorites', () => {
  beforeEach(() => {
    updateUISettings.mockClear();
    uiSettings.value = {};
  });

  it('favoritar manda a lista inteira, com o novo no fim', () => {
    uiSettings.value = { [FAVORITE_MENUS_KEY]: ['Tickets'] };
    const { toggleFavorite } = useSidebarFavorites();

    toggleFavorite('Agenda');

    expect(updateUISettings).toHaveBeenCalledWith({
      [FAVORITE_MENUS_KEY]: ['Tickets', 'Agenda'],
    });
  });

  it('desfavoritar tira so aquele item', () => {
    uiSettings.value = { [FAVORITE_MENUS_KEY]: ['Tickets', 'Agenda'] };
    const { toggleFavorite, isFavorite } = useSidebarFavorites();

    expect(isFavorite('Tickets')).toBe(true);
    toggleFavorite('Tickets');

    expect(updateUISettings).toHaveBeenCalledWith({
      [FAVORITE_MENUS_KEY]: ['Agenda'],
    });
  });

  it('valor salvo que nao e lista conta como sem favoritos', () => {
    uiSettings.value = { [FAVORITE_MENUS_KEY]: 'lixo' };
    const { favorites } = useSidebarFavorites();

    expect(favorites.value).toEqual([]);
  });
});
