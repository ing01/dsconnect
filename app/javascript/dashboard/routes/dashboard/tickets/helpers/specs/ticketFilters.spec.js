import { ticketMatchesFilters } from '../ticketFilters';

describe('ticketMatchesFilters - categoria', () => {
  const ticket = { id: 1, ticket_category_id: 4 };

  it('shows only the tickets of the chosen category', () => {
    expect(ticketMatchesFilters(ticket, { categoryId: 4 })).toBe(true);
    expect(ticketMatchesFilters(ticket, { categoryId: 5 })).toBe(false);
  });

  it('hides tickets without a category once one is chosen', () => {
    expect(
      ticketMatchesFilters(
        { id: 2, ticket_category_id: null },
        { categoryId: 4 }
      )
    ).toBe(false);
  });

  it('shows everything when no category is chosen', () => {
    expect(ticketMatchesFilters(ticket, { categoryId: null })).toBe(true);
    expect(ticketMatchesFilters(ticket, {})).toBe(true);
  });
});
