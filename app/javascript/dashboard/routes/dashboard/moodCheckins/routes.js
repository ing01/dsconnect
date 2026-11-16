import { frontendURL } from '../../../helper/URLHelper';
import MoodCheckinsIndex from './pages/MoodCheckinsIndex.vue';

const commonMeta = {
  permissions: ['administrator', 'mood_checkin_manage'],
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
