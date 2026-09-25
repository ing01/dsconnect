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
const create = vi.fn(() => ({ post, get, delete: del }));

vi.mock('axios', () => ({ default: { create } }));

vi.mock('dashboard/helper/clientSession', () => ({
  getClientSession: vi.fn(() => ({ token: 'token-do-cliente' })),
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

  // A conta nunca vai na URL: ela é a do contato autenticado, resolvida no
  // servidor. Sem id de conta na requisição não há id de conta para trocar.
  it('never puts an account id in the path', async () => {
    const api = await carregar();
    await api.board(7);
    await api.teams();
    await api.createTicket({ title: 'Chamado' });

    const caminhos = [
      ...get.mock.calls.map(c => c[0]),
      ...post.mock.calls.map(c => c[0]),
    ];
    expect(caminhos.every(caminho => !caminho.includes('accounts'))).toBe(true);
  });
});
