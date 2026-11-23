import { frontendURL } from '../../../helper/URLHelper';
import CompaniesIndex from './pages/CompaniesIndex.vue';
import CompanyDetailView from './pages/CompanyDetailView.vue';
import CompaniesManagement from './pages/CompaniesManagement.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.COMPANIES,
  permissions: ['administrator', 'agent', 'company_manage'],
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/companies'),
    component: CompaniesIndex,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'companies_dashboard_index',
        component: CompaniesIndex,
        meta: commonMeta,
      },
    ],
  },
  {
    // Antes de `:companyId`, que de outra forma leria "management" como um id.
    path: frontendURL('accounts/:accountId/companies/management'),
    component: CompaniesManagement,
    meta: { ...commonMeta, permissions: ['administrator'] },
    children: [
      {
        path: '',
        name: 'companies_management_index',
        component: CompaniesManagement,
        meta: { ...commonMeta, permissions: ['administrator'] },
      },
    ],
  },
  {
    path: frontendURL('accounts/:accountId/companies/:companyId'),
    component: CompanyDetailView,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'companies_dashboard_show',
        component: CompanyDetailView,
        meta: commonMeta,
      },
    ],
  },
];
