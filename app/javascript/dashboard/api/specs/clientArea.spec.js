import { describe, it, expect, vi, beforeEach } from 'vitest';

// Este arquivo existe por um defeito real: `clientArea.js` usava o `window.axios`
// global, que só é definido no bundle do painel. A tela de login roda no bundle
// `v3app`, sem esse global, e a chamada morria com ReferenceError antes de sair -
// a tela dizia "credenciais inválidas" para um cliente com a senha certa.
//
// Importar o axios é o que faz o módulo funcionar nos dois bundles, e é isso que
// os testes abaixo fixam.
const post = vi.fn(() => Promise.resolve({ data: {} }));
const get = vi.fn(() => Promise.resolve({ data: {} }));
const del = vi.fn(() => Promise.resolve({ data: {} }));
// Guarda o tratador de erro que o modulo registra, para os testes de 401
// abaixo poderem dispara-lo sem precisar de servidor.
let aoFalhar;
const use = vi.fn((_ok, erro) => {
  aoFalhar = erro;
});
const create = vi.fn(() => ({
  post,
  get,
  delete: del,
  interceptors: { response: { use } },
}));

vi.mock('axios', () => ({ default: { create } }));

const clearClientSession = vi.fn();
vi.mock('dashboard/helper/clientSession', () => ({
  getClientSession: vi.fn(() => ({ token: 'token-do-cliente' })),
  clearClientSession: (...a) => clearClientSession(...a),
}));

const carregar = async () => (await import('../clientArea')).default;

describe('clientArea API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.resetModules();
  });

  it('builds its own axios instance instead of using the global one', async () => {
    await carregar();

    expect(create).toHaveBeenCalled();
    // O global não é tocado: a tela de login não o tem.
    expect(window.axios).toBeUndefined();
  });

  it('signs in without sending any session header', async () => {
    const api = await carregar();
    await api.login({ email: 'cliente@exemplo.com.br', password: 'segredo' });

    expect(post).toHaveBeenCalledWith('/api/v1/client/session', {
      email: 'cliente@exemplo.com.br',
      password: 'segredo',
    });
  });

  it('carries the client token on the authenticated calls', async () => {
    const api = await carregar();
    await api.board();

    expect(get).toHaveBeenCalledWith('/api/v1/client/tickets', {
      headers: { api_access_token: 'token-do-cliente' },
      params: {},
    });
  });

  // Os filtros da lista saem com o nome que o servidor le, e o que esta vazio
  // nem vai na requisicao - sem `status` o servidor mostra so os abertos.
  it('sends only the filled list filters, with the server parameter names', async () => {
    const api = await carregar();
    await api.board(7, {
      teamId: 2,
      ticketColumnId: 15,
      assigneeId: null,
      status: 'closed',
      createdAfter: '2026-10-01',
      createdBefore: '',
    });

    expect(get).toHaveBeenCalledWith('/api/v1/client/tickets', {
      headers: { api_access_token: 'token-do-cliente' },
      params: {
        company_id: 7,
        team_id: 2,
        ticket_column_id: 15,
        status: 'closed',
        created_after: '2026-10-01',
      },
    });
  });

  // A conta nunca vai na URL: ela é a do contato autenticado, resolvida no
  // servidor. Sem id de conta na requisição não há id de conta para trocar.
  it('never puts an account id in the path', async () => {
    const api = await carregar();
    await api.board(7);
    await api.categories();
    await api.notifications();
    await api.createTicket({ title: 'Chamado' });

    const caminhos = [
      ...get.mock.calls.map(c => c[0]),
      ...post.mock.calls.map(c => c[0]),
    ];
    expect(caminhos.every(caminho => !caminho.includes('accounts'))).toBe(true);
  });

  // Sessao morta nao pode virar tela quebrada: o token do cookie deixa de
  // valer quando a equipe desliga o acesso, ou quando a propria pessoa
  // redefine a senha - que derruba as sessoes de proposito.
  describe('sessao expirada', () => {
    const assign = vi.fn();

    beforeEach(() => {
      assign.mockClear();
      clearClientSession.mockClear();
      delete window.location;
      window.location = { assign };
    });

    const dispararFalha = async (url, status) => {
      await carregar();
      await expect(
        aoFalhar({ config: { url }, response: { status } })
      ).rejects.toBeDefined();
    };

    it('drops the dead session and goes back to the login', async () => {
      await dispararFalha('/api/v1/client/tickets', 401);

      expect(clearClientSession).toHaveBeenCalled();
      expect(assign).toHaveBeenCalledWith('/app/login');
    });

    // No login o 401 e a resposta esperada para senha errada, e tem mensagem
    // propria na tela - redirecionar comeria o aviso.
    it('leaves the login screen alone', async () => {
      await dispararFalha('/api/v1/client/session', 401);

      expect(clearClientSession).not.toHaveBeenCalled();
      expect(assign).not.toHaveBeenCalled();
    });

    it('leaves the password reset screen alone', async () => {
      await dispararFalha('/api/v1/client/password', 401);

      expect(assign).not.toHaveBeenCalled();
    });

    // Outros erros nao derrubam ninguem: uma falha de rede nao e sessao morta.
    it('does not log anyone out on a different failure', async () => {
      await dispararFalha('/api/v1/client/tickets', 500);

      expect(clearClientSession).not.toHaveBeenCalled();
      expect(assign).not.toHaveBeenCalled();
    });
  });
});
