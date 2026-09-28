import { frontendURL } from 'dashboard/helper/URLHelper.js';
import ImplementationReportsPage from './pages/ImplementationReportsPage.vue';

const implementationReportsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/implementation-reports'),
      name: 'implementation_reports_index',
      meta: {
        permissions: ['administrator', 'agent', 'implementation_report_manage'],
      },
      component: ImplementationReportsPage,
    },
  ],
};

export default implementationReportsRoutes;
