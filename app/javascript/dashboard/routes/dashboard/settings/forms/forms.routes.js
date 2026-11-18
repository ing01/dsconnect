import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import FormsListPage from './FormsListPage.vue';
import FormBuilderPage from './FormBuilderPage.vue';

// Formularios (estilo Google Forms) - builder, vinculo com Catalogo de
// Servicos/Checklist/Artigo e historico de respostas por ticket.
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/forms'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'forms_list',
          meta: {
            permissions: ['administrator'],
          },
          component: FormsListPage,
        },
        {
          path: 'new',
          name: 'forms_new',
          meta: {
            permissions: ['administrator'],
          },
          component: FormBuilderPage,
        },
        {
          path: ':formId',
          name: 'forms_edit',
          meta: {
            permissions: ['administrator'],
          },
          component: FormBuilderPage,
        },
      ],
    },
  ],
};
