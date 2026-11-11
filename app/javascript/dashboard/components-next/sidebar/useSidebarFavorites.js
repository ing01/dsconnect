import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

// Chave em `ui_settings` do usuario: lista de `name` dos itens de topo do menu,
// na ordem em que foram favoritados. Fica no servidor, entao acompanha a pessoa
// em qualquer navegador.
export const FAVORITE_MENUS_KEY = 'sidebar_favorite_menus';

/**
 * Poe os favoritos no inicio do menu, na ordem em que foram favoritados, e
 * mantem o resto na ordem original. Nome que nao existe no menu (item removido,
 * sem permissao ou com a feature desligada) e ignorado em silencio. Nunca
 * libera um item: so reordena o que ja foi montado.
 * @param {Array<{name: string}>} items itens de topo do menu
 * @param {Array<string>} favorites nomes favoritados
 * @returns {Array} nova lista, sem alterar a original
 */
export const orderMenuItems = (items, favorites = []) => {
  if (!Array.isArray(favorites) || favorites.length === 0) return items;

  const byName = new Map(items.map(item => [item.name, item]));
  const pinned = [...new Set(favorites)]
    .map(name => byName.get(name))
    .filter(Boolean);
  const pinnedNames = new Set(pinned.map(item => item.name));

  return [...pinned, ...items.filter(item => !pinnedNames.has(item.name))];
};

export function useSidebarFavorites() {
  const { uiSettings, updateUISettings } = useUISettings();

  const favorites = computed(() => {
    const saved = uiSettings.value?.[FAVORITE_MENUS_KEY];
    return Array.isArray(saved) ? saved : [];
  });

  const isFavorite = name => favorites.value.includes(name);

  // O merge de `updateUISettings` e raso: sempre manda a lista inteira.
  const toggleFavorite = name => {
    const next = isFavorite(name)
      ? favorites.value.filter(item => item !== name)
      : [...favorites.value, name];
    updateUISettings({ [FAVORITE_MENUS_KEY]: next });
  };

  return { favorites, isFavorite, toggleFavorite };
}
