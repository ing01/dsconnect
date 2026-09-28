import { frontendURL } from 'dashboard/helper/URLHelper.js';
import SuggestionsPage from './pages/SuggestionsPage.vue';

// Transparencia combinada: qualquer agente ou administrador ve o quadro
// inteiro. So quem tem `suggestion_manage` (ou e administrador) arrasta os
// cards/configura as colunas - isso e checado dentro da pagina, nao aqui.
const suggestionsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/suggestions'),
      name: 'suggestions_index',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: SuggestionsPage,
    },
  ],
};

export default suggestionsRoutes;
