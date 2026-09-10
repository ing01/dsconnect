/* eslint-disable no-restricted-globals, no-console */
/* globals clients */

// Uma aba visivel recebe o aviso dentro da propria pagina, no canto inferior
// direito; a notificacao do sistema fica para quando ninguem esta olhando.
// Antes disto, quem ja estava com o site aberto levava um pop-up do sistema por
// cima do proprio site, avisando de algo que a tela ja mostrava.
//
// A decisao mora aqui, e nao no ActionCable, porque e um evento so: se a pagina
// escutasse por outro caminho, o mesmo aviso chegaria em dobro.
// "Dentro do site" e a janela em foco, nao apenas visivel. Uma aba aberta num
// segundo monitor enquanto a pessoa trabalha em outro programa conta como fora:
// o aviso dentro da pagina passaria despercebido, e e melhor pecar por uma
// notificacao do sistema a mais do que por uma que ninguem ve.
const focusedWindowClients = () =>
  clients
    .matchAll({ type: 'window', includeUncontrolled: true })
    .then(windowClients => windowClients.filter(client => client.focused));

self.addEventListener('push', event => {
  const notification = event.data && event.data.json();

  if (!notification) {
    return;
  }

  event.waitUntil(
    focusedWindowClients().then(focusedClients => {
      if (focusedClients.length) {
        focusedClients.forEach(client =>
          client.postMessage({ type: 'push_notification', notification })
        );
        // O navegador so dispensa a notificacao obrigatoria do `userVisibleOnly`
        // quando existe uma janela a vista - e uma janela em foco esta a vista.
        return undefined;
      }

      return self.registration.showNotification(notification.title, {
        tag: notification.tag,
        data: {
          url: notification.url,
        },
      });
    })
  );
});

self.addEventListener('notificationclick', event => {
  let notification = event.notification;

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(windowClients => {
      let matchingWindowClients = windowClients.filter(
        client => client.url === notification.data.url
      );

      if (matchingWindowClients.length) {
        let firstWindow = matchingWindowClients[0];
        if (firstWindow && 'focus' in firstWindow) {
          firstWindow.focus();
          return;
        }
      }
      if (clients.openWindow) {
        clients.openWindow(notification.data.url);
      }
    })
  );
});
