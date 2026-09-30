import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import StagesPage from './StagesPage.vue';
import CategoriesPage from './CategoriesPage.vue';
import ComplexityPage from './ComplexityPage.vue';
import CatalogPage from './CatalogPage.vue';
import PrioritiesPage from './PrioritiesPage.vue';
import AutomationPage from './AutomationPage.vue';
import AttendanceSchedulePage from './AttendanceSchedulePage.vue';
import ImportTicketsPage from './ImportTicketsPage.vue';

// One page per subject rather than a single scrolling screen: Estagios and
// Categorias belong to a Mesa, the Catalogo is account-wide, and mixing them
// made the page hard to read.
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
          component: StagesPage,
        },
        {
          path: 'priorities',
          name: 'ticket_priorities_list',
          meta: {
            permissions: ['administrator'],
          },
          component: PrioritiesPage,
        },
        {
          path: 'categories',
          name: 'ticket_categories_list',
          meta: {
            permissions: ['administrator'],
          },
          component: CategoriesPage,
        },
        {
          path: 'complexity',
          name: 'ticket_complexity_list',
          meta: {
            permissions: ['administrator'],
          },
          component: ComplexityPage,
        },
        {
          path: 'catalog',
          name: 'ticket_catalog_list',
          meta: {
            permissions: ['administrator'],
          },
          component: CatalogPage,
        },
        {
          path: 'automation',
          name: 'ticket_automation_settings',
          meta: {
            permissions: ['administrator'],
          },
          component: AutomationPage,
        },
        {
          path: 'attendance-schedule',
          name: 'ticket_attendance_schedule_settings',
          meta: {
            permissions: ['administrator'],
          },
          component: AttendanceSchedulePage,
        },
        {
          path: 'import',
          name: 'ticket_import_settings',
          meta: {
            permissions: ['administrator'],
          },
          component: ImportTicketsPage,
        },
      ],
    },
  ],
};
