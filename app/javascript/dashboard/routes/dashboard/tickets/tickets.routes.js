import { frontendURL } from 'dashboard/helper/URLHelper.js';

import TicketsWorkspaceRouteView from './pages/TicketsWorkspaceRouteView.vue';
import TicketsPage from './pages/TicketsPage.vue';
import TicketDetailPage from './pages/TicketDetailPage.vue';
import TicketTriagePage from './pages/TicketTriagePage.vue';

const meta = {
  permissions: ['administrator', 'agent', 'ticket_manage'],
};

// Both screens hang off one parent so the workspace tab bar is mounted once for
// the module. The paths and route names are unchanged - every existing link
// into a Ticket still resolves, and so do direct links and refreshes.
const ticketsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/tickets'),
      component: TicketsWorkspaceRouteView,
      children: [
        {
          path: '',
          name: 'tickets_index',
          meta,
          component: TicketsPage,
        },
        // Antes de `:ticketId`: senao "triage" seria lido como um id de ticket.
        {
          path: 'triage',
          name: 'tickets_triage',
          meta,
          component: TicketTriagePage,
        },
        {
          path: ':ticketId',
          name: 'ticket_detail',
          meta,
          component: TicketDetailPage,
        },
      ],
    },
  ],
};

export default ticketsRoutes;
