import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

export const COLOR_SCHEMES = ['light', 'dark', 'auto'];

/**
 * De onde sai o tema, em ordem de precedencia.
 *
 * 1. A escolha do USUARIO (`ui_settings.color_scheme`), que viaja com ele. Antes
 *    ela vivia so no `localStorage`, e `localStorage` e de um aparelho so: quem
 *    escolhia escuro no computador abria o sistema no celular e via claro, como
 *    se nunca tivesse escolhido nada.
 * 2. O que ficou gravado NESTE navegador. E o que a tela de login tem - ali
 *    ainda nao existe usuario de quem herdar preferencia.
 * 3. `auto`, que segue o sistema operacional.
 *
 * A escolha do usuario fica em memoria de modulo porque o tema e aplicado em
 * pontos que nao alcancam o store: o aviso de mudanca de tema do sistema
 * operacional, e a propria tela de login.
 */
let userColorScheme = null;

export const setUserColorScheme = scheme => {
  userColorScheme = COLOR_SCHEMES.includes(scheme) ? scheme : null;
};

export const storeColorScheme = scheme => {
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, scheme);
};

export const preferredColorScheme = () =>
  userColorScheme ||
  LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) ||
  'auto';

export const isOSOnDarkMode = () =>
  window.matchMedia('(prefers-color-scheme: dark)').matches;

// `dark` vai no `body` E no `documentElement`: o painel estiliza a partir do
// `body`, a tela de login a partir da raiz, e a raiz tambem pinta o fundo da
// pagina antes de qualquer componente montar - sem ela o celular dava um flash
// branco no carregamento.
export const setColorTheme = isOSInDarkMode => {
  const scheme = preferredColorScheme();
  const isDark = scheme === 'dark' || (scheme === 'auto' && isOSInDarkMode);

  document.body.classList.toggle('dark', isDark);
  document.documentElement.classList.toggle('dark', isDark);
  document.documentElement.style.setProperty(
    'color-scheme',
    isDark ? 'dark' : 'light'
  );

  return isDark;
};

// Aplica o tema lendo o sistema operacional por conta propria - o caso comum de
// quem so quer "deixa o tema certo agora".
export const applyColorScheme = () => setColorTheme(isOSOnDarkMode());
