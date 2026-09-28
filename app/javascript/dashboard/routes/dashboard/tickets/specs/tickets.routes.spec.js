import { createRouter, createMemoryHistory } from 'vue-router';
import ticketsRoutes from '../tickets.routes';

// The workspace put both screens under one parent so the tab bar is mounted
// once for the module. Nesting is exactly the kind of change that silently
// moves URLs, and every link into a Ticket in this app is built by hand with
// `frontendURL` - so what the module promises is pinned here: same paths, same
// route names, same permissions.
const router = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: ticketsRoutes.routes,
  });

describe('ticketsRoutes', () => {
  it('keeps the Kanban on its own URL', () => {
    const resolved = router().resolve('/app/accounts/1/tickets');

    expect(resolved.name).toBe('tickets_index');
  });

  it('keeps a Ticket on its own URL', () => {
    const resolved = router().resolve('/app/accounts/1/tickets/26');

    expect(resolved.name).toBe('ticket_detail');
    expect(resolved.params).toEqual({ accountId: '1', ticketId: '26' });
  });

  // The global guard sends any route without a name to the dashboard, so the
  // index child must stay named even though its path is empty.
  it('names every route a user can land on', () => {
    ['/app/accounts/1/tickets', '/app/accounts/1/tickets/26'].forEach(path => {
      expect(router().resolve(path).name).toBeTruthy();
    });
  });

  // Permissions are read off the matched route, and the parent carries none:
  // were they left only on the parent, both screens would be open to anyone.
  it('carries the permissions into both screens', () => {
    ['/app/accounts/1/tickets', '/app/accounts/1/tickets/26'].forEach(path => {
      expect(router().resolve(path).meta.permissions).toEqual([
        'administrator',
        'agent',
        'ticket_manage',
      ]);
    });
  });

  it('renders both screens inside the workspace shell', () => {
    const resolved = router().resolve('/app/accounts/1/tickets/26');

    expect(resolved.matched).toHaveLength(2);
  });
});
