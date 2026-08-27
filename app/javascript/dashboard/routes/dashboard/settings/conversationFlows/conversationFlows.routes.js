import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';
import FlowEditor from './FlowEditor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/conversation-flows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'conversation_flows_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'conversation_flows_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'conversation_flows_list',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
        {
          path: ':conversationFlowId',
          name: 'conversation_flows_edit',
          meta: {
            permissions: ['administrator'],
          },
          component: FlowEditor,
        },
      ],
    },
  ],
};
