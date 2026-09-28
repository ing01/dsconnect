import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import SuggestionColumnsPage from './SuggestionColumnsPage.vue';

// So quem administra o quadro (administrator ou `suggestion_manage`) configura
// as colunas - diferente da rota do quadro em si, aberta a qualquer agente.
const meta = {
  permissions: ['administrator', 'suggestion_manage'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/suggestions'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'suggestion_columns_list',
          meta,
          component: SuggestionColumnsPage,
        },
      ],
    },
  ],
};
