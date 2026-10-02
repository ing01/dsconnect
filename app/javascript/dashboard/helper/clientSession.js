/**
 * A sessão da Área do Cliente.
 *
 * Um cookie próprio, separado do `cw_d_session_info` do usuário interno: as duas
 * sessões podem coexistir no mesmo navegador sem uma sobrescrever a outra, e o
 * fluxo do usuário interno não muda em nada por existir esta.
 */
import Cookies from 'js-cookie';

const CHAVE = 'cw_client_session';

// O prefixo das rotas da Área do Cliente. Fica aqui para a guarda de rotas e o
// boot do painel perguntarem a mesma coisa do mesmo lugar.
export const CLIENT_PATH = '/app/client';

export const isClientArea = () =>
  window.location.pathname.startsWith(CLIENT_PATH);

export const setClientSession = ({ api_access_token: token, contact }) => {
  Cookies.set(CHAVE, JSON.stringify({ token, contact }), { expires: 30 });
};

export const getClientSession = () => {
  const bruto = Cookies.get(CHAVE);
  if (!bruto) return null;
  try {
    return JSON.parse(bruto);
  } catch {
    // Cookie corrompido é o mesmo que sessão nenhuma - melhor mandar para o
    // login do que quebrar a tela com um JSON pela metade.
    return null;
  }
};

export const hasClientSession = () => Boolean(getClientSession()?.token);

export const clearClientSession = () => Cookies.remove(CHAVE);

/**
 * O idioma da Área do Cliente: português, SEMPRE.
 *
 * Regra absoluta, e não um padrão - a conta não opina, o contato não opina, o
 * navegador de quem acessa não opina. Espelha `ClientAreaLocale::LOCALE` no
 * servidor, que é onde a regra está escrita; as duas pontas precisam concordar,
 * senão a tela sai num idioma e a mensagem de erro que ela mostra, em outro.
 *
 * Sem isto a área renderizava no inglês em que o i18n do painel nasce, porque o
 * ajuste de idioma de lá depende do usuário interno, que aqui não existe.
 */
export const CLIENT_LOCALE = 'pt_BR';

export const clientLocale = () => CLIENT_LOCALE;

/**
 * Se o menu lateral está recolhido.
 *
 * Guardado no navegador porque o contato não tem `ui_settings` de usuário, que
 * é onde o painel interno guarda a largura da barra. É preferência de quem
 * olha, não do cadastro.
 */
const CHAVE_MENU = 'cw_client_sidebar_collapsed';

export const isSidebarCollapsed = () => {
  try {
    return window.localStorage.getItem(CHAVE_MENU) === 'true';
  } catch {
    // Navegador com armazenamento bloqueado: o menu abre, que é o padrão.
    return false;
  }
};

export const setSidebarCollapsed = valor => {
  try {
    window.localStorage.setItem(CHAVE_MENU, String(valor));
  } catch {
    // Não poder lembrar a preferência não pode derrubar a tela.
  }
};

/**
 * Como o cliente prefere ver os chamados: em lista ou no Kanban.
 *
 * Guardado no navegador pelo mesmo motivo do menu lateral - o contato nao tem
 * `ui_settings`. E preferencia de leitura: quem acompanha poucos chamados tende
 * a querer a lista, quem acompanha o andamento quer o quadro.
 */
const CHAVE_VISAO = 'cw_client_tickets_view';

export const VISOES = ['list', 'kanban'];

export const getTicketsView = () => {
  try {
    const salvo = window.localStorage.getItem(CHAVE_VISAO);
    return VISOES.includes(salvo) ? salvo : 'list';
  } catch {
    // Armazenamento bloqueado: cai no padrao, que e a lista - foi o que
    // pediram como visao principal.
    return 'list';
  }
};

export const setTicketsView = valor => {
  try {
    window.localStorage.setItem(CHAVE_VISAO, valor);
  } catch {
    // Nao poder lembrar a preferencia nao pode derrubar a tela.
  }
};

/**
 * Se o contato ja viu o tutorial guiado do Portal (primeiro acesso).
 *
 * Guardado por CONTATO (nao so' por navegador) dentro de uma unica chave -
 * um objeto `{ [contactId]: true }` - porque o mesmo navegador/dispositivo
 * pode ser usado por mais de um contato (ex.: computador compartilhado da
 * empresa cliente), e cada um deve ver o tutorial na sua propria primeira
 * vez, independente do que outro contato ja viu ali.
 */
const CHAVE_TUTORIAL = 'cw_client_tutorial_seen';

const lerVistos = () => {
  try {
    const bruto = window.localStorage.getItem(CHAVE_TUTORIAL);
    const vistos = bruto ? JSON.parse(bruto) : {};
    return vistos && typeof vistos === 'object' ? vistos : {};
  } catch {
    return {};
  }
};

export const hasSeenTutorial = contactId => {
  if (!contactId) return true;
  return Boolean(lerVistos()[contactId]);
};

export const setTutorialSeen = contactId => {
  if (!contactId) return;
  try {
    const vistos = lerVistos();
    vistos[contactId] = true;
    window.localStorage.setItem(CHAVE_TUTORIAL, JSON.stringify(vistos));
  } catch {
    // Nao poder lembrar a preferencia nao pode derrubar a tela - so' significa
    // que o tutorial pode aparecer de novo no proximo acesso.
  }
};
