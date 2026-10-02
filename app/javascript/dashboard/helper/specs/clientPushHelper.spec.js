import ClientAreaAPI from 'dashboard/api/clientArea';

vi.mock('dashboard/api/clientArea', () => ({
  default: { registerPushSubscription: vi.fn(() => Promise.resolve()) },
}));

// `btoa`/`Uint8Array` existem no jsdom, mas `getKey` da inscricao real nao -
// uma chave fake de duas posicoes basta para o helper gerar a string.
const fakeSubscription = {
  endpoint: 'https://push.exemplo/abc',
  getKey: () => new Uint8Array([1, 2]),
};

const mockServiceWorker = (subscription = fakeSubscription) => {
  const pushManager = { subscribe: vi.fn(() => Promise.resolve(subscription)) };
  const registration = { pushManager };
  Object.defineProperty(window.navigator, 'serviceWorker', {
    configurable: true,
    value: {
      register: vi.fn(() => Promise.resolve(registration)),
      ready: Promise.resolve(registration),
    },
  });
};

const clearServiceWorker = () => {
  Object.defineProperty(window.navigator, 'serviceWorker', {
    configurable: true,
    value: undefined,
  });
};

const mockNotification = permission => {
  window.Notification = { permission, requestPermission: vi.fn() };
};

const clearNotification = () => {
  delete window.Notification;
};

const mockPushManager = () => {
  window.PushManager = function PushManager() {};
};

const clearPushManager = () => {
  delete window.PushManager;
};

describe('o push do Portal do Cliente', () => {
  beforeEach(() => {
    vi.resetModules();
    window.chatwootConfig = { vapidPublicKey: new Uint8Array([9, 9]) };
    mockPushManager();
  });

  afterEach(() => {
    clearServiceWorker();
    clearNotification();
    clearPushManager();
    delete window.chatwootConfig;
    vi.restoreAllMocks();
  });

  describe('clientPushSupported', () => {
    it('is false without a browser API the feature needs', async () => {
      clearNotification();
      const { clientPushSupported } = await import('../clientPushHelper');

      expect(clientPushSupported()).toBe(false);
    });

    it('is true when the three APIs are present', async () => {
      mockServiceWorker();
      mockNotification('default');
      const { clientPushSupported } = await import('../clientPushHelper');

      expect(clientPushSupported()).toBe(true);
    });
  });

  describe('ensureClientPushSubscribed', () => {
    // O ponto do pedido: permissao concedida por um caminho que nunca passou
    // pelo nosso botao - o Android pergunta sozinho ao instalar o app, ou a
    // pessoa liga direto nas Configuracoes do aparelho - ainda assim registra
    // a inscricao no servidor, sem pedir nada de novo.
    it('registers the subscription when permission is already granted, asking nothing', async () => {
      mockServiceWorker();
      mockNotification('granted');
      const { ensureClientPushSubscribed } = await import(
        '../clientPushHelper'
      );

      const resultado = await ensureClientPushSubscribed();

      expect(resultado).toBe(true);
      expect(window.Notification.requestPermission).not.toHaveBeenCalled();
      expect(ClientAreaAPI.registerPushSubscription).toHaveBeenCalledWith({
        endpoint: 'https://push.exemplo/abc',
        p256dh: expect.any(String),
        auth: expect.any(String),
      });
    });

    it('does nothing while permission is still unanswered', async () => {
      mockServiceWorker();
      mockNotification('default');
      const { ensureClientPushSubscribed } = await import(
        '../clientPushHelper'
      );

      expect(await ensureClientPushSubscribed()).toBe(false);
      expect(ClientAreaAPI.registerPushSubscription).not.toHaveBeenCalled();
    });

    it('does nothing once permission was denied', async () => {
      mockServiceWorker();
      mockNotification('denied');
      const { ensureClientPushSubscribed } = await import(
        '../clientPushHelper'
      );

      expect(await ensureClientPushSubscribed()).toBe(false);
      expect(ClientAreaAPI.registerPushSubscription).not.toHaveBeenCalled();
    });

    // Repete a toda carga da Area do Cliente (ClientLayout.vue) - precisa ser
    // seguro repetir. `subscribe()` do proprio navegador ja devolve a MESMA
    // inscricao quando ja existe uma; aqui so' se confirma que o helper nao
    // trava nem duplica ao ser chamado de novo.
    it('is safe to call again - idempotent on repeated boots', async () => {
      mockServiceWorker();
      mockNotification('granted');
      const { ensureClientPushSubscribed } = await import(
        '../clientPushHelper'
      );

      await ensureClientPushSubscribed();
      await ensureClientPushSubscribed();

      expect(ClientAreaAPI.registerPushSubscription).toHaveBeenCalledTimes(2);
    });

    it('resolves to false, without throwing, when the browser refuses the subscription', async () => {
      mockNotification('granted');
      Object.defineProperty(window.navigator, 'serviceWorker', {
        configurable: true,
        value: {
          register: vi.fn(() => Promise.reject(new Error('sem permissao'))),
        },
      });
      const { ensureClientPushSubscribed } = await import(
        '../clientPushHelper'
      );

      await expect(ensureClientPushSubscribed()).resolves.toBe(false);
    });
  });

  describe('requestClientPushPermission', () => {
    it('subscribes right away when permission is already granted', async () => {
      mockServiceWorker();
      mockNotification('granted');
      const { requestClientPushPermission } = await import(
        '../clientPushHelper'
      );

      expect(await requestClientPushPermission()).toBe(true);
      expect(window.Notification.requestPermission).not.toHaveBeenCalled();
    });

    it('does not prompt again once denied', async () => {
      mockServiceWorker();
      mockNotification('denied');
      const { requestClientPushPermission } = await import(
        '../clientPushHelper'
      );

      expect(await requestClientPushPermission()).toBe(false);
      expect(window.Notification.requestPermission).not.toHaveBeenCalled();
    });

    it('asks the browser and subscribes once granted', async () => {
      mockServiceWorker();
      mockNotification('default');
      window.Notification.requestPermission = vi.fn(callback => {
        callback('granted');
      });
      const { requestClientPushPermission } = await import(
        '../clientPushHelper'
      );

      expect(await requestClientPushPermission()).toBe(true);
      expect(ClientAreaAPI.registerPushSubscription).toHaveBeenCalled();
    });
  });
});
