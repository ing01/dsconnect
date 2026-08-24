import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/tickets'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'ticket_settings_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'ticket_stages_list', params: to.params };
          },
        },
        {
          path: 'stages',
          name: 'ticket_stages_list',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
