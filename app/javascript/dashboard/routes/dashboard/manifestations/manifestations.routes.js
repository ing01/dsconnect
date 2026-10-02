import { frontendURL } from 'dashboard/helper/URLHelper.js';
import ManifestationsPage from './pages/ManifestationsPage.vue';
import ManifestationDetailPage from './pages/ManifestationDetailPage.vue';

// O SAC do lado da equipe.
//
// Toda a equipe le e responde - uma reclamacao parada por falta de permissao e
// pior do que uma vista por quem nao precisava. O que fica restrito ao
// administrador (converter em ticket, excluir) e checado no
// ManifestationPolicy, no servidor, e nao aqui: a rota so decide quem entra na
// tela.
const manifestationsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/manifestations'),
      name: 'manifestations_index',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: ManifestationsPage,
    },
    {
      path: frontendURL('accounts/:accountId/manifestations/:manifestationId'),
      name: 'manifestation_detail',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: ManifestationDetailPage,
    },
  ],
};

export default manifestationsRoutes;
