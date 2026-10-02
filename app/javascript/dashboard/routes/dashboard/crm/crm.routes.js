import { frontendURL } from 'dashboard/helper/URLHelper.js';
import CrmClientsPage from './pages/CrmClientsPage.vue';
import CrmSalesPage from './pages/CrmSalesPage.vue';

// Acesso restrito: SO quem tiver `commercial_manage` (custom_role) ve este
// menu - de proposito SEM 'administrator'/'agent' na lista, ao contrario do
// resto do app (ver Crm::ClientPolicy/Crm::SalePolicy no backend).
const crmRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/crm/clients'),
      name: 'crm_clients_index',
      meta: {
        permissions: ['commercial_manage'],
      },
      component: CrmClientsPage,
    },
    {
      path: frontendURL('accounts/:accountId/crm/sales'),
      name: 'crm_sales_index',
      meta: {
        permissions: ['commercial_manage'],
      },
      component: CrmSalesPage,
    },
  ],
};

export default crmRoutes;
