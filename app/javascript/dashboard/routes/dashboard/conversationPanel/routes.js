import { frontendURL } from '../../../helper/URLHelper';
import ConversationPanelPage from './pages/ConversationPanelPage.vue';

// Administrador sempre; os demais só com a permissão `conversation_panel_view`
// na Função personalizada.
const commonMeta = {
  permissions: ['administrator', 'conversation_panel_view'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/conversation-panel'),
    name: 'conversation_panel_index',
    component: ConversationPanelPage,
    meta: commonMeta,
  },
];
