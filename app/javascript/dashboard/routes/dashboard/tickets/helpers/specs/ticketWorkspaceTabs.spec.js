import {
  neighbourTabId,
  readWorkspaceTabs,
  workspaceTabsKey,
  writeWorkspaceTabs,
} from '../ticketWorkspaceTabs';

describe('ticketWorkspaceTabs', () => {
  beforeEach(() => window.localStorage.clear());

  it('keeps one entry per account and user', () => {
    expect(workspaceTabsKey(1, 7)).toBe('ticket-workspace-tabs::1::7');
    expect(workspaceTabsKey(1, 7)).not.toBe(workspaceTabsKey(2, 7));
  });

  it('round-trips the open tabs', () => {
    writeWorkspaceTabs(1, 7, { ticketIds: [26, 27], activeTicketId: 27 });

    expect(readWorkspaceTabs(1, 7)).toEqual({
      ticketIds: [26, 27],
      activeTicketId: 27,
    });
  });

  it('reads nothing for a user with no stored tabs', () => {
    expect(readWorkspaceTabs(1, 7)).toEqual({
      ticketIds: [],
      activeTicketId: null,
    });
  });

  it('drops an active id that is not among the tabs', () => {
    writeWorkspaceTabs(1, 7, { ticketIds: [26], activeTicketId: 99 });

    expect(readWorkspaceTabs(1, 7).activeTicketId).toBeNull();
  });

  it('survives a corrupted entry', () => {
    window.localStorage.setItem(workspaceTabsKey(1, 7), 'not json');

    expect(readWorkspaceTabs(1, 7).ticketIds).toEqual([]);
  });

  describe('neighbourTabId', () => {
    it('falls back to the tab on the left', () => {
      expect(neighbourTabId([26, 27, 31], 27)).toBe(26);
    });

    it('falls back to the right at the head of the bar', () => {
      expect(neighbourTabId([26, 27, 31], 26)).toBe(27);
    });

    it('returns null when the bar empties', () => {
      expect(neighbourTabId([26], 26)).toBeNull();
    });
  });
});
