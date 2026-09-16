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
// A escolha passa a ser a do navegador, quando houver traducao para ela.
// `pt-BR` vira `pt_BR`, que e como as pastas de traducao sao nomeadas; se so
// houver o idioma base (`pt`), ele tambem serve. Sem correspondencia, cai no
// padrao do produto.
const DEFAULT_LOCALE = 'pt_BR';

const resolveLocale = () => {
  const requested = window.navigator?.language;
  if (!requested) return DEFAULT_LOCALE;

  const normalized = requested.replace('-', '_');
  const base = normalized.split('_')[0];

  if (i18nMessages[normalized]) return normalized;
  if (i18nMessages[base]) return base;

  return DEFAULT_LOCALE;
};

const i18n = createI18n({
  legacy: false, // https://github.com/intlify/vue-i18n/issues/1902
  locale: resolveLocale(),
  fallbackLocale: DEFAULT_LOCALE,
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
