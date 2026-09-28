import { frontendURL } from '../../../helper/URLHelper';
import AgendaPage from './pages/AgendaPage.vue';

const commonMeta = {
  permissions: ['administrator', 'agent', 'agenda_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/agenda'),
    component: AgendaPage,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'agenda_index',
        component: AgendaPage,
        meta: commonMeta,
      },
    ],
  },
];
