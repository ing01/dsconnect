import { frontendURL } from 'dashboard/helper/URLHelper.js';
import CrmClientsPage from './pages/CrmClientsPage.vue';
import CrmSalesPage from './pages/CrmSalesPage.vue';

// Acesso: administrador da conta ve automaticamente; qualquer outro usuario
// precisa de `commercial_manage` (custom_role) atribuida pela Ingrid (ver
// Crm::ClientPolicy/Crm::SalePolicy no backend).
const crmRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/crm/clients'),
      name: 'crm_clients_index',
      meta: {
        permissions: ['administrator', 'commercial_manage'],
      },
      component: CrmClientsPage,
    },
    {
      path: frontendURL('accounts/:accountId/crm/sales'),
      name: 'crm_sales_index',
      meta: {
        permissions: ['administrator', 'commercial_manage'],
      },
      component: CrmSalesPage,
    },
  ],
};

export default crmRoutes;
