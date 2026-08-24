import {
  collapsedColumnsKey,
  readCollapsedColumnIds,
  writeCollapsedColumnIds,
  toggleCollapsedColumn,
} from '../collapsedColumns';

describe('collapsedColumns', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it('scopes the storage key by account and Mesa', () => {
    expect(collapsedColumnsKey(1, 7)).toBe(
      'ticket-kanban-collapsed-columns::1::7'
    );
  });

  it('returns an empty list when nothing was stored', () => {
    expect(readCollapsedColumnIds(1, 7)).toEqual([]);
  });

  it('round-trips the collapsed ids', () => {
    writeCollapsedColumnIds(1, 7, [12, 15]);

    expect(readCollapsedColumnIds(1, 7)).toEqual([12, 15]);
  });

  it('toggles an id on and back off', () => {
    expect(toggleCollapsedColumn(1, 7, 12)).toEqual([12]);
    expect(readCollapsedColumnIds(1, 7)).toEqual([12]);

    expect(toggleCollapsedColumn(1, 7, 12)).toEqual([]);
    expect(readCollapsedColumnIds(1, 7)).toEqual([]);
  });

  it('keeps the state of each Mesa independent', () => {
    toggleCollapsedColumn(1, 7, 12);

    expect(readCollapsedColumnIds(1, 8)).toEqual([]);
    expect(readCollapsedColumnIds(1, 7)).toEqual([12]);
  });

  it('keeps the state of each account independent', () => {
    toggleCollapsedColumn(1, 7, 12);

    expect(readCollapsedColumnIds(2, 7)).toEqual([]);
  });

  it('prunes ids of Estagios that no longer exist', () => {
    writeCollapsedColumnIds(1, 7, [12, 15]);

    expect(readCollapsedColumnIds(1, 7, [15])).toEqual([15]);
  });

  it('survives malformed stored data', () => {
    window.localStorage.setItem(collapsedColumnsKey(1, 7), 'not json');

    expect(readCollapsedColumnIds(1, 7)).toEqual([]);
  });
});
