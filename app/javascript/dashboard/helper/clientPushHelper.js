/* eslint-disable no-console */
// O mesmo mecanismo VAPID de `pushHelper.js`, so que a inscricao e' enviada
// como CONTATO (`ClientAreaAPI.registerPushSubscription`), e nao como usuario
// interno - por isso um arquivo proprio, em vez de reaproveitar aquele.
import ClientAreaAPI from 'dashboard/api/clientArea';

const generateKeys = str =>
  btoa(String.fromCharCode.apply(null, new Uint8Array(str)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

const subscriptionPayload = subscription => ({
  endpoint: subscription.endpoint,
  p256dh: generateKeys(subscription.getKey('p256dh')),
  auth: generateKeys(subscription.getKey('auth')),
});

const registerSubscription = () => {
  if (!window.chatwootConfig?.vapidPublicKey) return Promise.resolve();

  return navigator.serviceWorker
    .register('/sw.js')
    .then(() => navigator.serviceWorker.ready)
    .then(registration =>
      registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: window.chatwootConfig.vapidPublicKey,
      })
    )
    .then(subscription =>
      ClientAreaAPI.registerPushSubscription(subscriptionPayload(subscription))
    );
};

export const clientPushSupported = () =>
  'serviceWorker' in navigator &&
  'PushManager' in window &&
  'Notification' in window;

export const clientPushPermission = () =>
  clientPushSupported() ? Notification.permission : 'unsupported';

// So chamado a partir de um clique - pedir permissao sem gesto do usuario e'
// ignorado (ou pior, queima a unica chance) na maioria dos navegadores.
export const requestClientPushPermission = () => {
  if (!clientPushSupported()) return Promise.resolve(false);

  if (Notification.permission === 'granted') {
    return registerSubscription()
      .then(() => true)
      .catch(error => {
        console.error('Client push subscription failed:', error);
        return false;
      });
  }

  if (Notification.permission === 'denied') return Promise.resolve(false);

  return new Promise(resolve => {
    Notification.requestPermission(permission => {
      if (permission !== 'granted') {
        resolve(false);
        return;
      }
      registerSubscription()
        .then(() => resolve(true))
        .catch(error => {
          console.error('Client push subscription failed:', error);
          resolve(false);
        });
    });
  });
};
