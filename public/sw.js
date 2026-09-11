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

// Um service worker novo normalmente fica EM ESPERA ate a pessoa fechar todas
// as abas do site - e enquanto isso o antigo continua respondendo. Foi o que fez
// a notificacao chegar so com o titulo depois de o corpo ja estar publicado: o
// servidor mandava o texto e a versao velha, que nao sabia repassa-lo, e que
// atendia. Como este worker so trata notificacao e nao serve arquivo nenhum
// (nao ha handler de `fetch`), assumir o lugar na hora nao arrisca servir asset
// velho para pagina nova.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(clients.claim()));

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
        body: notification.body,
        tag: notification.tag,
        data: {
          url: notification.url,
        },
      });
    })
  );
});

// O servidor manda um CAMINHO, sem host, e quem sabe o host certo e o navegador:
// resolvemos contra a origem deste service worker, que e sempre o endereco pelo
// qual a pessoa entrou. Assim o clique nao depende do FRONTEND_URL do servidor,
// que envelhece a cada troca de endereco. URL absoluta antiga continua valendo -
// o segundo argumento do `URL` so entra em acao quando o primeiro e relativo.
const absoluteUrl = url => new URL(url, self.location.origin).href;

self.addEventListener('notificationclick', event => {
  const notification = event.notification;
  const url = absoluteUrl(notification.data.url);

  notification.close();

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(windowClients => {
        // Compara so o caminho: a mesma tela pode estar aberta com outro hash ou
        // com parametros de rastreio, e uma igualdade exata abriria uma segunda
        // janela para a conversa que ja esta na frente da pessoa.
        const target = new URL(url);
        const match = windowClients.find(client => {
          try {
            return new URL(client.url).pathname === target.pathname;
          } catch (error) {
            return false;
          }
        });

        if (match && 'focus' in match) {
          return match.focus();
        }

        return clients.openWindow ? clients.openWindow(url) : undefined;
      })
  );
});
