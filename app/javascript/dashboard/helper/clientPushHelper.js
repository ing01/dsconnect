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

// Garante a inscricao quando a permissao JA esta concedida, sem pedir nada -
// `subscribe()` nao exige gesto do usuario quando a permissao ja foi dada,
// so `requestPermission()` exige.
//
// Existe porque a permissao pode ter sido concedida por um caminho que nunca
// passou pelo nosso botao: o Android pergunta sozinho ao instalar o app como
// PWA, e tambem da para ligar a notificacao direto nas Configuracoes do
// aparelho. Nos dois casos `Notification.permission` vira 'granted' sem que
// `registerSubscription` seja chamado - e sem ele nao existe
// `ClientPushSubscription` nenhuma no servidor para onde mandar o aviso. A
// pessoa achava que tinha ativado e nunca recebia nada.
//
// Chamado no boot da Area do Cliente (`ClientLayout.vue`), nao so na tela de
// chat: e o que cobre quem acabou de instalar e nunca abriu aquela tela.
// Idempotente dos dois lados - o navegador devolve a MESMA inscricao se ja
// existir, e o servidor so acha-ou-cria pelo endpoint
// (`PushSubscriptionsController#create`) -, entao chamar de novo a cada boot
// nao duplica nada.
export const ensureClientPushSubscribed = () => {
  if (!clientPushSupported()) return Promise.resolve(false);
  if (Notification.permission !== 'granted') return Promise.resolve(false);

  return registerSubscription()
    .then(() => true)
    .catch(error => {
      console.error('Client push subscription failed:', error);
      return false;
    });
};

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
