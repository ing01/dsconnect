import { frontendURL } from 'dashboard/helper/URLHelper.js';
import PrincipalPage from './pages/PrincipalPage.vue';

const principalRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/principal'),
      name: 'principal',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: PrincipalPage,
    },
  ],
};

export default principalRoutes;
