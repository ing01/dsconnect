/**
 * As rotas da Área do Cliente.
 *
 * Vivem no mesmo SPA do painel interno de propósito: é assim que os componentes,
 * os estilos e os modais existentes são reaproveitados de verdade, em vez de
 * copiados para uma segunda aplicação.
 *
 * Quem entra aqui é barrado pela guarda em `routes/index.js`, que exige sessão
 * de cliente - e não sessão de usuário interno.
 */
import ClientLayout from './ClientLayout.vue';
import ClientPrincipalPage from './pages/ClientPrincipalPage.vue';
import ClientTicketsPage from './pages/ClientTicketsPage.vue';
import ClientTicketDetailPage from './pages/ClientTicketDetailPage.vue';
import ClientChatPage from './pages/ClientChatPage.vue';
import ClientChatHistoryPage from './pages/ClientChatHistoryPage.vue';
import ClientChatHistoryDetailPage from './pages/ClientChatHistoryDetailPage.vue';
import ClientNotificationsPage from './pages/ClientNotificationsPage.vue';
import ClientManifestationsPage from './pages/ClientManifestationsPage.vue';
import ClientManifestationDetailPage from './pages/ClientManifestationDetailPage.vue';
import ClientPasswordEditPage from './pages/ClientPasswordEditPage.vue';
import ClientInstallPage from './pages/ClientInstallPage.vue';

// A definicao de nova senha e o link de instalacao rodam SEM sessao - o
// primeiro e o token do e-mail que autoriza, o segundo e de proposito (um
// link pronto para mandar a alguem que ainda nem tem acesso, so para
// instalar o app antes de entrar). Ficam listados aqui para a guarda em
// `routes/index.js` saber liberar so estes.
export const CLIENT_PUBLIC_PATHS = [
  '/app/client/password/edit',
  '/app/client/install',
];

export default {
  routes: [
    {
      // Fora do ClientLayout de proposito: o menu lateral e o cabecalho leem o
      // contato logado, que nesta tela ainda nao existe.
      path: '/app/client/password/edit',
      name: 'client_password_edit',
      component: ClientPasswordEditPage,
    },
    {
      path: '/app/client/install',
      name: 'client_install',
      component: ClientInstallPage,
    },
    {
      path: '/app/client',
      component: ClientLayout,
      children: [
        {
          // O "Principal" do cliente: novidades do PRODUTO, mesmo esquema do
          // Principal dos atendentes - e nao mais um redirecionamento direto
          // para os tickets.
          path: '',
          name: 'client_home',
          component: ClientPrincipalPage,
        },
        {
          path: 'tickets',
          name: 'client_tickets',
          component: ClientTicketsPage,
        },
        {
          path: 'tickets/:ticketId',
          name: 'client_ticket_detail',
          component: ClientTicketDetailPage,
        },
        {
          path: 'chat',
          name: 'client_chat',
          component: ClientChatPage,
        },
        {
          path: 'chat/history',
          name: 'client_chat_history',
          component: ClientChatHistoryPage,
        },
        {
          path: 'chat/history/:conversationId',
          name: 'client_chat_history_detail',
          component: ClientChatHistoryDetailPage,
        },
        {
          // O SAC: sugestoes, reclamacoes, elogios e pedidos de melhoria.
          path: 'sac',
          name: 'client_manifestations',
          component: ClientManifestationsPage,
        },
        {
          path: 'sac/:manifestationId',
          name: 'client_manifestation_detail',
          component: ClientManifestationDetailPage,
        },
        {
          path: 'notifications',
          name: 'client_notifications',
          component: ClientNotificationsPage,
        },
      ],
    },
  ],
};
