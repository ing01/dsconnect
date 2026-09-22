import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/products'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'products_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'products_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'products_list',
          meta: {
            featureFlag: FEATURE_FLAGS.COMPANIES,
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
