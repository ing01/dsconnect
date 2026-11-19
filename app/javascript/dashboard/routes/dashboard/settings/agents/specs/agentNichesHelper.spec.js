import {
  namesFor,
  filterAgents,
  filterItems,
  toggleId,
  sameIds,
} from '../agentNichesHelper';

const niches = [
  { id: 1, name: 'Variedades' },
  { id: 2, name: 'Indústria de alimentos' },
];
const subNiches = [
  { id: 10, name: 'Padaria / panificadora' },
  { id: 11, name: 'Informática' },
];
const agents = [
  { id: 1, name: 'Ingrid', niche_ids: [1], sub_niche_ids: [] },
  { id: 2, name: 'João Vitor', niche_ids: [2], sub_niche_ids: [10] },
  { id: 3, name: 'Lucas Oliveira', niche_ids: [], sub_niche_ids: [11] },
];

describe('agentNichesHelper', () => {
  it('turns ids into names, skipping the unknown ones', () => {
    expect(namesFor([2, 99, 1], niches)).toEqual([
      'Indústria de alimentos',
      'Variedades',
    ]);
    expect(namesFor(undefined, niches)).toEqual([]);
  });

  it('finds agents by their name, ignoring case and accents', () => {
    expect(
      filterAgents(agents, 'JOAO', niches, subNiches).map(a => a.id)
    ).toEqual([2]);
  });

  it('finds agents by a niche or by a sub-niche they cover', () => {
    expect(
      filterAgents(agents, 'alimentos', niches, subNiches).map(a => a.id)
    ).toEqual([2]);
    expect(
      filterAgents(agents, 'informatica', niches, subNiches).map(a => a.id)
    ).toEqual([3]);
  });

  it('shows everybody without a search, and nobody when nothing matches', () => {
    expect(filterAgents(agents, '  ', niches, subNiches)).toHaveLength(3);
    expect(filterAgents(agents, 'inexistente', niches, subNiches)).toEqual([]);
  });

  it('filters the editor lists by name', () => {
    expect(filterItems(subNiches, 'padaria').map(i => i.id)).toEqual([10]);
    expect(filterItems(subNiches, '')).toHaveLength(2);
  });

  it('toggles an id without changing the original list', () => {
    const original = [1, 2];

    expect(toggleId(original, 3)).toEqual([1, 2, 3]);
    expect(toggleId(original, 1)).toEqual([2]);
    expect(original).toEqual([1, 2]);
  });

  it('compares the saved ids with the edited ones, ignoring the order', () => {
    expect(sameIds([1, 2], [2, 1])).toBe(true);
    expect(sameIds([1], [1, 2])).toBe(false);
    expect(sameIds(undefined, [])).toBe(true);
  });
});
