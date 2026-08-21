import { frontendURL } from '../../../helper/URLHelper';
import MoodCheckinsIndex from './pages/MoodCheckinsIndex.vue';

const commonMeta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/mood-checkins'),
    component: MoodCheckinsIndex,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'mood_checkins_index',
        component: MoodCheckinsIndex,
        meta: commonMeta,
      },
    ],
  },
];
