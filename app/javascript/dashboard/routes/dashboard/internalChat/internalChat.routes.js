import { frontendURL } from 'dashboard/helper/URLHelper.js';

import InternalChatPage from './pages/InternalChatPage.vue';

// O Chat Interno e a comunicacao entre funcionarios, deliberadamente separada
// das Conversations com clientes e de qualquer coisa dentro do Ticket. Por isso
// tem rota propria em vez de uma aba dentro de um modulo existente.
const internalChatRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/internal-chat'),
      name: 'internal_chat',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: InternalChatPage,
    },
  ],
};

export default internalChatRoutes;
