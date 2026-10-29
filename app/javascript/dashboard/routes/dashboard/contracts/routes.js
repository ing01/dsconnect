import { frontendURL } from '../../../helper/URLHelper';
import ContractsIndex from './pages/ContractsIndex.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.COMPANIES,
  // 'commercial_manage': a lista abre por um botao em Comercial > Contratos.
  permissions: [
    'administrator',
    'agent',
    'company_manage',
    'commercial_manage',
  ],
  installationTypes: [INSTALLATION_TYPES.CLOUD, INSTALLATION_TYPES.ENTERPRISE],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/contracts'),
    component: ContractsIndex,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'contracts_dashboard_index',
        component: ContractsIndex,
        meta: commonMeta,
      },
    ],
  },
];
