import { frontendURL } from 'dashboard/helper/URLHelper.js';
import MonthlySatisfactionSurveysPage from './pages/MonthlySatisfactionSurveysPage.vue';

// So LEITURA, aberta a qualquer agente - mesma regra de transparencia que a
// policy do backend ja aplica (ver MonthlySatisfactionSurveyPolicy).
const monthlySatisfactionSurveysRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/monthly-satisfaction-surveys'),
      name: 'monthly_satisfaction_surveys_index',
      meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      component: MonthlySatisfactionSurveysPage,
    },
  ],
};

export default monthlySatisfactionSurveysRoutes;
