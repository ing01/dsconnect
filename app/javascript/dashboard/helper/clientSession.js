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

// `password_change_required`: quem entrou com a senha padrao so' pode trocar a
// senha. Guardado junto da sessao para a guarda de rotas barrar o resto sem uma
// ida ao servidor (o servidor tambem barra - isto so evita telas quebradas).
export const setClientSession = ({
  api_access_token: token,
  contact,
  password_change_required: passwordChangeRequired = false,
}) => {
  Cookies.set(
    CHAVE,
    JSON.stringify({
      token,
      contact,
      passwordChangeRequired: Boolean(passwordChangeRequired),
    }),
    { expires: 30 }
  );
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

// A tela de troca da senha padrao.
export const CLIENT_PASSWORD_CHANGE_PATH = '/app/client/password/change';

export const mustChangeClientPassword = () =>
  Boolean(getClientSession()?.passwordChangeRequired);

// Depois da troca: mantem a sessao e so' desliga a exigencia.
export const markClientPasswordChanged = () => {
  const sessao = getClientSession();
  if (!sessao) return;
  Cookies.set(
    CHAVE,
    JSON.stringify({ ...sessao, passwordChangeRequired: false }),
    {
      expires: 30,
    }
  );
};

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
 * Se a pessoa DESLIGOU as notificações pelo botão do cabeçalho.
 *
 * O navegador não deixa a página revogar a permissão: depois de desligar, ela
 * continua "concedida". Sem lembrar da escolha, a inscrição automática do boot
 * (`ensureClientPushSubscribed`) religaria tudo na próxima visita. Vale para o
 * navegador, não para o contato.
 */
const CHAVE_PUSH_DESLIGADO = 'cw_client_push_opted_out';

export const isClientPushOptedOut = () => {
  try {
    return window.localStorage.getItem(CHAVE_PUSH_DESLIGADO) === 'true';
  } catch {
    return false;
  }
};

export const setClientPushOptedOut = valor => {
  try {
    window.localStorage.setItem(CHAVE_PUSH_DESLIGADO, String(valor));
  } catch {
    // Não poder lembrar a escolha não pode derrubar a tela.
  }
};

/**
 * Se a pessoa ja escolheu "Continuar na Web" no aviso do app mobile.
 *
 * Em `localStorage`: quem prefere o navegador nao quer ser perguntado a cada
 * visita. Vale para o aparelho, e nao para o contato - o aviso aparece ate no
 * login, quando ainda nao ha contato.
 */
const CHAVE_AVISO_APP = 'cw_mobile_app_prompt_dismissed';

export const hasDismissedMobileAppPrompt = () => {
  try {
    return window.localStorage.getItem(CHAVE_AVISO_APP) === 'true';
  } catch {
    // Armazenamento bloqueado: nao da para lembrar, entao o aviso volta a cada
    // visita - melhor do que nunca mostrar.
    return false;
  }
};

export const setMobileAppPromptDismissed = () => {
  try {
    window.localStorage.setItem(CHAVE_AVISO_APP, 'true');
  } catch {
    // Nao poder lembrar a escolha nao pode derrubar a tela.
  }
};

/**
 * Se o contato "adiou" a Avaliacao Mensal nesta sessao do navegador.
 *
 * De proposito em `sessionStorage`, nao em `localStorage`: isto NUNCA e' a
 * fonte da verdade sobre "ja respondeu" (isso e' sempre o servidor, via
 * `getMonthlySurveyStatus`) - serve so' para nao insistir em abrir o modal de
 * novo a cada troca de tela dentro da MESMA sessao, depois que a pessoa
 * clicou em adiar. Fechar a aba e voltar depois faz o modal aparecer de novo,
 * o que e' o comportamento desejado. Guardado por contato+mes, porque um novo
 * mes de referencia e' uma pergunta nova.
 */
const CHAVE_SURVEY_ADIADA = 'cw_client_monthly_survey_dismissed';

export const hasDismissedMonthlySurvey = (contactId, referenceMonth) => {
  try {
    return (
      window.sessionStorage.getItem(CHAVE_SURVEY_ADIADA) ===
      `${contactId}:${referenceMonth}`
    );
  } catch {
    return false;
  }
};

export const setMonthlySurveyDismissed = (contactId, referenceMonth) => {
  try {
    window.sessionStorage.setItem(
      CHAVE_SURVEY_ADIADA,
      `${contactId}:${referenceMonth}`
    );
  } catch {
    // Nao poder lembrar nao pode derrubar a tela - so' significa que o modal
    // pode insistir de novo na proxima troca de tela.
  }
};
