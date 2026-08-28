import { frontendURL } from 'dashboard/helper/URLHelper.js';
import ProjectsPage from './pages/ProjectsPage.vue';

const projectsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/projects'),
      name: 'projects_index',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: ProjectsPage,
    },
  ],
};

export default projectsRoutes;
