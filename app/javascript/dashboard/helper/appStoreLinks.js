// Onde baixar o app mobile (Flutter, em `mobile/`).
export const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.duesoft.dsconnect_mobile';

export const APP_STORE_URL =
  'https://apps.apple.com/br/app/dsconnect/id6825573035';

// Navegador de celular ou tablet. O iPadOS pede o site de desktop e se
// apresenta como Mac, entao ele so se reconhece pela tela de toque.
export const isMobileDevice = () =>
  /android|iphone|ipad|ipod/i.test(window.navigator.userAgent) ||
  (window.navigator.platform === 'MacIntel' &&
    window.navigator.maxTouchPoints > 1);
