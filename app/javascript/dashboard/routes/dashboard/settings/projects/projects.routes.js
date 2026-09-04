import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import ModulesPage from './ModulesPage.vue';
import TaskTemplatesPage from './TaskTemplatesPage.vue';
import ChecklistsPage from './ChecklistsPage.vue';

// Settings for the Projetos de Implantacao feature: Modulos and Tarefas
// (task templates). Distinct from routes/dashboard/projects/projects.routes.js,
// which is the Projects Kanban itself.
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/projects'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'project_settings_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: to => {
            return { name: 'project_modules_list', params: to.params };
          },
        },
        {
          path: 'modules',
          name: 'project_modules_list',
          meta: {
            permissions: ['administrator'],
          },
          component: ModulesPage,
        },
        {
          path: 'tasks',
          name: 'project_tasks_list',
          meta: {
            permissions: ['administrator'],
          },
          component: TaskTemplatesPage,
        },
        {
          path: 'checklists',
          name: 'project_checklists_list',
          meta: {
            permissions: ['administrator'],
          },
          component: ChecklistsPage,
        },
      ],
    },
  ],
};
