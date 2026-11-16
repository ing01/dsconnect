import { openInWorkspaceTab, wantsWorkspaceTab } from '../openInWorkspaceTab';
import { useTicketWorkspace } from '../../composables/useTicketWorkspace';

describe('openInWorkspaceTab', () => {
  const ticket = {
    id: 7,
    display_id: 70,
    company_name: 'Acme',
    title: 'Erro',
    requester_name: 'Ana',
  };

  it('recognises Ctrl and Cmd, and nothing else', () => {
    expect(wantsWorkspaceTab({ ctrlKey: true })).toBe(true);
    expect(wantsWorkspaceTab({ metaKey: true })).toBe(true);
    expect(wantsWorkspaceTab({ shiftKey: true })).toBe(false);
    expect(wantsWorkspaceTab(undefined)).toBe(false);
  });

  it('adds the tab without activating it on Ctrl+click', () => {
    const { tabs, activeId } = useTicketWorkspace();

    const opened = openInWorkspaceTab(ticket, { ctrlKey: true });

    expect(opened).toBe(true);
    expect(tabs.value.map(tab => tab.id)).toContain(7);
    expect(activeId.value).not.toBe(7);
  });

  it('does nothing on a plain click', () => {
    const { tabs } = useTicketWorkspace();
    const before = tabs.value.length;

    expect(openInWorkspaceTab({ ...ticket, id: 8 }, {})).toBe(false);
    expect(tabs.value).toHaveLength(before);
  });
});
