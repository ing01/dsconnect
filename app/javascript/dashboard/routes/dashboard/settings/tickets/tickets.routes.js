import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import StagesPage from './StagesPage.vue';
import CategoriesPage from './CategoriesPage.vue';
import CatalogPage from './CatalogPage.vue';

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
          path: 'categories',
          name: 'ticket_categories_list',
          meta: {
            permissions: ['administrator'],
          },
          component: CategoriesPage,
        },
        {
          path: 'catalog',
          name: 'ticket_catalog_list',
          meta: {
            permissions: ['administrator'],
          },
          component: CatalogPage,
        },
      ],
    },
  ],
};
