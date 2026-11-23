import { canCancelTickets, CANCEL_PERMISSION } from '../ticketPermissions';

describe('canCancelTickets', () => {
  it('lets the administrator cancel', () => {
    expect(canCancelTickets('administrator', ['administrator'])).toBe(true);
  });

  it('lets a custom role that has the cancel permission cancel', () => {
    expect(
      canCancelTickets('custom_role', [
        'ticket_manage',
        CANCEL_PERMISSION,
        'custom_role',
      ])
    ).toBe(true);
  });

  it('keeps a plain agent and a custom role without the permission out', () => {
    expect(canCancelTickets('agent', ['agent'])).toBe(false);
    expect(
      canCancelTickets('custom_role', ['ticket_manage', 'custom_role'])
    ).toBe(false);
    expect(canCancelTickets('agent')).toBe(false);
    expect(canCancelTickets('agent', null)).toBe(false);
  });
});
