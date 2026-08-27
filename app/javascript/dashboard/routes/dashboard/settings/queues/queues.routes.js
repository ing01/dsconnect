import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/queues'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'queues_wrapper',
          meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
          },
          redirect: to => {
            return { name: 'settings_queues_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'settings_queues_list',
          meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
          },
          component: Index,
        },
      ],
    },
  ],
};
