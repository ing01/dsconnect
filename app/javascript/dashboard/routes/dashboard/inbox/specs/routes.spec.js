import { INBOX_PERMISSIONS } from '../permissions';
import { hasPermissions } from 'dashboard/helper/permissionsHelper';
import { AVAILABLE_CUSTOM_ROLE_PERMISSIONS } from 'dashboard/constants/permissions';

describe('Inbox (Notificacoes) permissions', () => {
  it('are always open to administrators and agents', () => {
    expect(hasPermissions(INBOX_PERMISSIONS, ['administrator'])).toBe(true);
    expect(hasPermissions(INBOX_PERMISSIONS, ['agent'])).toBe(true);
  });

  // O que a conta de uma funcao personalizada carrega: as permissoes dela + 'custom_role'.
  it('are open to a custom role that has the notification permission', () => {
    expect(
      hasPermissions(INBOX_PERMISSIONS, [
        'ticket_manage',
        'notification_view',
        'custom_role',
      ])
    ).toBe(true);
  });

  it('stay closed to a custom role without the notification permission', () => {
    expect(
      hasPermissions(INBOX_PERMISSIONS, ['ticket_manage', 'custom_role'])
    ).toBe(false);
  });

  it('is one of the permissions a custom role can be given', () => {
    expect(AVAILABLE_CUSTOM_ROLE_PERMISSIONS).toContain('notification_view');
  });
});
