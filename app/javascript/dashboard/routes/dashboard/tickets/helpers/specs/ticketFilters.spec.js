import { ticketMatchesFilters, UNASSIGNED_AGENT_ID } from '../ticketFilters';

describe('ticketMatchesFilters - sem ticket pai', () => {
  const solto = { id: 1, parent_id: null };
  const filho = { id: 2, parent_id: 9 };

  it('mostra os dois por padrao', () => {
    expect(ticketMatchesFilters(solto, {})).toBe(true);
    expect(ticketMatchesFilters(solto, { hideWithoutParent: false })).toBe(
      true
    );
  });

  it('esconde so quem nao tem pai quando pedido', () => {
    expect(ticketMatchesFilters(solto, { hideWithoutParent: true })).toBe(
      false
    );
    expect(ticketMatchesFilters(filho, { hideWithoutParent: true })).toBe(true);
  });
});

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

describe('ticketMatchesFilters - Sem responsavel', () => {
  const none = { id: 1, assignee_id: null };
  const noKey = { id: 2 };
  const ana = { id: 3, assignee_id: 9 };

  it('shows only the tickets with nobody assigned when it is the only choice', () => {
    const filters = { assigneeIds: [UNASSIGNED_AGENT_ID] };

    expect(ticketMatchesFilters(none, filters)).toBe(true);
    expect(ticketMatchesFilters(noKey, filters)).toBe(true);
    expect(ticketMatchesFilters(ana, filters)).toBe(false);
  });

  it('adds up with agents: that agent OR nobody', () => {
    const filters = { assigneeIds: [9, UNASSIGNED_AGENT_ID] };

    expect(ticketMatchesFilters(none, filters)).toBe(true);
    expect(ticketMatchesFilters(ana, filters)).toBe(true);
    expect(ticketMatchesFilters({ id: 4, assignee_id: 10 }, filters)).toBe(
      false
    );
  });

  it('hides the unassigned tickets when only agents are chosen, and shows all with no filter', () => {
    expect(ticketMatchesFilters(none, { assigneeIds: [9] })).toBe(false);
    expect(ticketMatchesFilters(none, { assigneeIds: [] })).toBe(true);
  });
});
