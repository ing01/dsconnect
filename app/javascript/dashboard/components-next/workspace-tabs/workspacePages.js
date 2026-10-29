import { LocalStorage } from 'shared/helpers/localStorage';

// Quais telas (fora os tickets) estão abertas na barra de abas é preferência de
// quem vê, como as abas de tickets: fica no localStorage, por conta e usuário, e
// nunca vai para a API. Só se guarda o mínimo para reabrir a tela - a chave do
// item de menu e o último caminho (com filtros e página) dentro dele.
export const PAGE_TABS_KEY_PREFIX = 'workspace-page-tabs';

export const PRINCIPAL_KEY_PREFIX = 'principal|';

const pageTabsKey = (accountId, userId) =>
  `${PAGE_TABS_KEY_PREFIX}::${accountId}::${userId}`;

const DEFAULT_ICON = 'i-lucide-panel-top';

const paramsOf = to => {
  // eslint-disable-next-line no-unused-vars
  const { accountId, ...rest } = to?.params || {};
  return rest;
};

const stableParams = params =>
  JSON.stringify(
    Object.keys(params)
      .sort()
      .map(name => [name, String(params[name])])
  );

// A chave de uma tela é a rota do item de menu + os parâmetros dela que não são
// a conta: "Time Suporte" e "Time Vendas" usam a mesma rota e são telas
// diferentes.
export const entryKey = to => `${to.name}|${stableParams(paramsOf(to))}`;

/**
 * Achata o menu lateral na lista de telas que podem virar aba.
 *
 * O menu já sabe o nome, o ícone e as rotas de cada tela (`to` e `activeOn`),
 * então a barra de abas não mantém uma lista paralela: o que aparece no menu
 * vira aba, e uma tela nova do menu ganha aba sem ninguém mexer aqui.
 */
export const flattenMenu = (items = [], parent = null, parentIcon = null) =>
  items.flatMap(item => {
    // Ícones desenhados por `h()` (marcadores coloridos) não servem para a aba:
    // herda o do item de cima.
    const icon = typeof item.icon === 'string' ? item.icon : parentIcon;
    const label =
      parent?.collapsible && parent.label
        ? `${parent.label}: ${item.label}`
        : item.label;

    const own = item.to?.name
      ? [
          {
            key: entryKey(item.to),
            names: [...new Set([item.to.name, ...(item.activeOn || [])])],
            params: paramsOf(item.to),
            label,
            icon: icon || DEFAULT_ICON,
            to: item.to,
          },
        ]
      : [];

    return [...own, ...flattenMenu(item.children || [], item, icon)];
  });

/**
 * Qual item do menu a rota atual representa.
 *
 * 1) a rota do próprio item, com os mesmos parâmetros (o time/marcador certo);
 * 2) uma rota "filha" listada em `activeOn` (o detalhe de uma empresa continua
 *    na aba "Todas as empresas");
 * 3) o mesmo, quando o item pede um parâmetro que a rota nem tem.
 */
export const resolveEntry = (catalog, route) => {
  if (!route?.name) return null;

  const candidates = catalog.filter(entry => entry.names.includes(route.name));
  if (!candidates.length) return null;

  const routeParams = paramsOf(route);
  const sameParams = entry =>
    Object.entries(entry.params).every(
      ([name, value]) => String(routeParams[name]) === String(value)
    );
  const missingParams = entry =>
    Object.keys(entry.params).every(name => !(name in routeParams));

  return (
    candidates.find(entry => entry.to.name === route.name && sameParams(entry)) ||
    candidates.find(sameParams) ||
    candidates.find(missingParams) ||
    null
  );
};

const isTab = tab =>
  tab && typeof tab.key === 'string' && typeof tab.path === 'string';

export const readPageTabs = (accountId, userId) => {
  const stored = LocalStorage.get(pageTabsKey(accountId, userId));
  const seen = new Set();

  return (Array.isArray(stored) ? stored : []).filter(tab => {
    if (!isTab(tab) || seen.has(tab.key)) return false;
    seen.add(tab.key);
    return true;
  });
};

export const writePageTabs = (accountId, userId, tabs) =>
  LocalStorage.set(
    pageTabsKey(accountId, userId),
    tabs.map(({ key, label, icon, path }) => ({ key, label, icon, path }))
  );

// Qual aba assume quando a ativa é fechada: a da esquerda, como nas abas de
// tickets - fechar uma sequência volta pelo caminho em que foram abertas. Só na
// ponta esquerda cai para a da direita; barra vazia devolve null.
export const neighbourItem = (items, closedId) => {
  const index = items.findIndex(item => item.id === closedId);
  if (index === -1) return null;

  const remaining = items.filter(item => item.id !== closedId);
  return remaining.length ? remaining[Math.max(index - 1, 0)] : null;
};
