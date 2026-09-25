import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';

import i18nMessages from 'dashboard/i18n';
import * as Sentry from '@sentry/vue';
import {
  initializeAnalyticsEvents,
  initializeChatwootEvents,
} from 'dashboard/helper/scriptHelpers';
import App from '../v3/App.vue';
import router, { initalizeRouter } from '../v3/views/index';
import store from '../v3/store';
import FluentIcon from 'shared/components/FluentIcon/DashboardIcon.vue';
// import { emitter } from '../shared/helpers/mitt';

// [VITE] This was added in https://github.com/chatwoot/chatwoot/commit/b57063a8b83c86819bd285f481298d7cd38ad50e
// Commenting it out for Vite migration
// Vue.config.env = process.env;

// As telas do v3 (login, cadastro, redefinicao de senha) sao anteriores ao
// login, entao nao ha usuario nem conta de onde tirar o idioma. Ficava 'en'
// fixo, e o login aparecia em ingles para todo mundo.
//
// Portugues, SEMPRE - inclusive aqui, que e o bundle do login, do cadastro e da
// redefinicao de senha. Seguir `navigator.language`, como era antes, punha a
// tela de entrada em ingles no navegador de quem estivesse com outro idioma,
// que e justamente o que nao se quer.
//
// Mesma regra de `ClientAreaLocale::LOCALE` no servidor.
const LOCALE = 'pt_BR';

const i18n = createI18n({
  legacy: false, // https://github.com/intlify/vue-i18n/issues/1902
  locale: LOCALE,
  fallbackLocale: LOCALE,
  messages: i18nMessages,
});

const app = createApp(App);
app.use(i18n);
app.use(store);
app.use(router);

// Vue.use(VueRouter);
// Vue.use(VueI18n);
// Vue.prototype.$emitter = emitter;
app.component('fluent-icon', FluentIcon);

if (window.errorLoggingConfig) {
  Sentry.init({
    app,
    dsn: window.errorLoggingConfig,
    denyUrls: [
      // Chrome extensions
      /^chrome:\/\//i,
      /chrome-extension:/i,
      /extensions\//i,

      // Locally saved copies
      /file:\/\//i,

      // Safari extensions.
      /safari-web-extension:/i,
      /safari-extension:/i,
    ],
    integrations: [Sentry.browserTracingIntegration({ router })],
    ignoreErrors: [
      'ResizeObserver loop completed with undelivered notifications',
    ],
  });
}

initializeChatwootEvents();
initializeAnalyticsEvents();
initalizeRouter();

window.onload = () => {
  app.mount('#app');
};
