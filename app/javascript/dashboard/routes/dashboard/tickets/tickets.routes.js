import { frontendURL } from 'dashboard/helper/URLHelper.js';

import TicketsPage from './pages/TicketsPage.vue';
import TicketDetailPage from './pages/TicketDetailPage.vue';

const ticketsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/tickets'),
      name: 'tickets_index',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: TicketsPage,
    },
    {
      path: frontendURL('accounts/:accountId/tickets/:ticketId'),
      name: 'ticket_detail',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: TicketDetailPage,
    },
  ],
};

export default ticketsRoutes;
