import { describe, it, expect, vi, beforeEach } from 'vitest';

// A Área do Cliente é em português. O i18n do painel nasce em inglês e só é
// ajustado a partir do usuário interno - que aqui não existe -, então o padrão
// precisa estar escrito em algum lugar. É este.
const cookies = {};

vi.mock('js-cookie', () => ({
  default: {
    get: chave => cookies[chave],
    set: (chave, valor) => {
      cookies[chave] = valor;
    },
    remove: chave => {
      delete cookies[chave];
    },
  },
}));

const carregar = async () => import('../clientSession');

describe('clientSession', () => {
  beforeEach(() => {
    Object.keys(cookies).forEach(k => delete cookies[k]);
    vi.resetModules();
  });

  it('uses the account locale when the session carries one', async () => {
    const { setClientSession, clientLocale } = await carregar();
    setClientSession({ api_access_token: 'x', contact: { locale: 'en' } });

    expect(clientLocale()).toBe('en');
  });

  // O caso que trouxe o bug: sessão aberta antes de o campo existir.
  it('falls back to pt_BR when the session has no locale', async () => {
    const { setClientSession, clientLocale } = await carregar();
    setClientSession({ api_access_token: 'x', contact: { name: 'Cliente' } });

    expect(clientLocale()).toBe('pt_BR');
  });

  it('falls back to pt_BR when there is no session at all', async () => {
    const { clientLocale } = await carregar();

    expect(clientLocale()).toBe('pt_BR');
  });

  // `isClientArea` decide quem manda no idioma: é ela que faz o `setLocale` do
  // App.vue sair de cena. O App.vue aplica `window.chatwootConfig.selectedLocale`
  // no `mounted`, e esse valor vem do `I18n.locale` do servidor - que, sem
  // sessão de usuário, é o padrão da instalação (inglês). Foi isso que desfez a
  // correção de idioma na primeira tentativa.
  describe('isClientArea', () => {
    const emPath = async caminho => {
      window.history.replaceState({}, '', caminho);
      const { isClientArea } = await carregar();
      return isClientArea();
    };

    it('recognises the client area', async () => {
      expect(await emPath('/app/client/tickets')).toBe(true);
      expect(await emPath('/app/client/tickets/12')).toBe(true);
    });

    it('leaves the internal dashboard alone', async () => {
      expect(await emPath('/app/accounts/1/tickets')).toBe(false);
      expect(await emPath('/app/login')).toBe(false);
    });
  });

  // O menu recolhido é preferência de quem olha, e o contato não tem
  // `ui_settings` de usuário - por isso fica no navegador.
  describe('menu recolhido', () => {
    it('starts expanded', async () => {
      const { isSidebarCollapsed } = await carregar();

      expect(isSidebarCollapsed()).toBe(false);
    });

    it('remembers the choice', async () => {
      const { isSidebarCollapsed, setSidebarCollapsed } = await carregar();

      setSidebarCollapsed(true);
      expect(isSidebarCollapsed()).toBe(true);

      setSidebarCollapsed(false);
      expect(isSidebarCollapsed()).toBe(false);
    });

    // Navegador com armazenamento bloqueado não pode derrubar a tela.
    it('survives storage being unavailable', async () => {
      const original = window.localStorage;
      Object.defineProperty(window, 'localStorage', {
        configurable: true,
        get() {
          throw new Error('bloqueado');
        },
      });

      const { isSidebarCollapsed, setSidebarCollapsed } = await carregar();
      expect(isSidebarCollapsed()).toBe(false);
      expect(() => setSidebarCollapsed(true)).not.toThrow();

      Object.defineProperty(window, 'localStorage', {
        configurable: true,
        value: original,
      });
    });
  });

  // Cookie corrompido é o mesmo que sessão nenhuma - não pode derrubar a tela.
  it('survives a corrupted cookie', async () => {
    const { getClientSession, hasClientSession } = await carregar();
    cookies.cw_client_session = '{pela metade';

    expect(getClientSession()).toBeNull();
    expect(hasClientSession()).toBe(false);
  });
});
