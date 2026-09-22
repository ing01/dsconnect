import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/product-groups'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'product_groups_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'product_groups_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'product_groups_list',
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
