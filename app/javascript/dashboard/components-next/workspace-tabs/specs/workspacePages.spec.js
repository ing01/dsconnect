import {
  entryKey,
  flattenMenu,
  neighbourItem,
  readPageTabs,
  resolveEntry,
  writePageTabs,
} from '../workspacePages';

const to = (name, params = {}) => ({
  name,
  params: { accountId: 1, ...params },
  query: {},
});

const MENU = [
  {
    name: 'Principal',
    label: 'Principal',
    icon: 'i-lucide-layout-dashboard',
    to: to('principal'),
    activeOn: ['principal'],
  },
  {
    name: 'Conversation',
    label: 'Conversas',
    icon: 'i-lucide-message-circle',
    children: [
      {
        name: 'All',
        label: 'Todas',
        icon: 'i-lucide-inbox',
        to: to('home'),
        activeOn: ['inbox_conversation'],
      },
      {
        name: 'Teams',
        label: 'Times',
        collapsible: true,
        children: [
          { name: 'a', label: 'Suporte', to: to('team_conversations', { teamId: 1 }) },
          { name: 'b', label: 'Vendas', to: to('team_conversations', { teamId: 2 }) },
        ],
      },
    ],
  },
  {
    name: 'Companies',
    label: 'Empresas',
    icon: 'i-lucide-building-2',
    children: [
      {
        name: 'All Companies',
        label: 'Todas as empresas',
        to: to('companies_dashboard_index'),
        activeOn: ['companies_dashboard_index', 'companies_dashboard_show'],
      },
    ],
  },
  { name: 'Auto Updater', label: 'Atualizador', href: 'https://exemplo.com' },
];

describe('flattenMenu', () => {
  const catalog = flattenMenu(MENU);

  it('keeps only the items that lead to a route', () => {
    expect(catalog.map(entry => entry.label)).toEqual([
      'Principal',
      'Todas',
      'Times: Suporte',
      'Times: Vendas',
      'Todas as empresas',
    ]);
  });

  it('inherits the icon of the group when the item has none', () => {
    const empresas = catalog.find(entry => entry.label === 'Todas as empresas');
    expect(empresas.icon).toBe('i-lucide-building-2');
  });

  it('gives the same route different keys when the params differ', () => {
    const [suporte, vendas] = catalog.filter(entry =>
      entry.label.startsWith('Times')
    );
    expect(suporte.key).not.toBe(vendas.key);
    expect(entryKey(to('principal'))).toBe('principal|[]');
  });
});

describe('resolveEntry', () => {
  const catalog = flattenMenu(MENU);
  const labelOf = route => resolveEntry(catalog, route)?.label;

  it('finds the item by its own route', () => {
    expect(labelOf({ name: 'principal', params: { accountId: '1' } })).toBe(
      'Principal'
    );
  });

  it('tells two items of the same route apart by their params', () => {
    const route = name => ({
      name,
      params: { accountId: '1', teamId: '2' },
    });
    expect(labelOf(route('team_conversations'))).toBe('Times: Vendas');
  });

  it('keeps a detail route inside the item that lists it in activeOn', () => {
    expect(
      labelOf({
        name: 'companies_dashboard_show',
        params: { accountId: '1', companyId: '9' },
      })
    ).toBe('Todas as empresas');
    expect(
      labelOf({
        name: 'inbox_conversation',
        params: { accountId: '1', conversation_id: '5' },
      })
    ).toBe('Todas');
  });

  it('returns null for a route that is not in the menu', () => {
    expect(labelOf({ name: 'ticket_detail', params: {} })).toBeUndefined();
    expect(resolveEntry(catalog, { params: {} })).toBeNull();
  });
});

describe('neighbourItem', () => {
  const items = ['a', 'b', 'c'].map(id => ({ id }));

  it('falls to the tab on the left', () => {
    expect(neighbourItem(items, 'c').id).toBe('b');
    expect(neighbourItem(items, 'b').id).toBe('a');
  });

  it('falls to the right only at the head of the bar', () => {
    expect(neighbourItem(items, 'a').id).toBe('b');
  });

  it('returns null when the bar would be empty or the tab is unknown', () => {
    expect(neighbourItem([{ id: 'a' }], 'a')).toBeNull();
    expect(neighbourItem(items, 'z')).toBeNull();
  });
});

describe('stored page tabs', () => {
  beforeEach(() => window.localStorage.clear());

  it('round-trips only the fields needed to reopen a tab', () => {
    writePageTabs(1, 7, [
      { key: 'a|[]', label: 'A', icon: 'i-x', path: '/app/a', extra: 'x' },
    ]);

    expect(readPageTabs(1, 7)).toEqual([
      { key: 'a|[]', label: 'A', icon: 'i-x', path: '/app/a' },
    ]);
  });

  it('drops malformed and duplicated entries', () => {
    window.localStorage.setItem(
      'workspace-page-tabs::1::8',
      JSON.stringify([
        { key: 'a|[]', path: '/a' },
        { key: 'a|[]', path: '/again' },
        { nope: true },
        null,
      ])
    );

    expect(readPageTabs(1, 8)).toHaveLength(1);
  });

  it('keeps accounts and users apart', () => {
    writePageTabs(1, 7, [{ key: 'a|[]', path: '/a' }]);

    expect(readPageTabs(2, 7)).toEqual([]);
    expect(readPageTabs(1, 9)).toEqual([]);
  });
});
