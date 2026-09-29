import {
  applyColorScheme,
  isOSOnDarkMode,
  preferredColorScheme,
  setColorTheme,
  setUserColorScheme,
  storeColorScheme,
} from 'dashboard/helper/themeHelper.js';
import { LocalStorage } from 'shared/helpers/localStorage';

vi.mock('shared/helpers/localStorage');

// O estado de modulo (a escolha do usuario) atravessa exemplos; cada um comeca
// sem ela, como um carregamento novo da pagina.
beforeEach(() => setUserColorScheme(null));

describe('setColorTheme', () => {
  it('should set body class to dark if selectedColorScheme is dark', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should set body class to dark if selectedColorScheme is auto and isOSOnDarkMode is true', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should not set body class to dark if selectedColorScheme is auto and isOSOnDarkMode is false', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(false);
    expect(document.body.classList.contains('dark')).toBe(false);
  });

  it('should not set body class to dark if selectedColorScheme is light', () => {
    LocalStorage.get.mockReturnValue('light');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(false);
  });

  it('should not set body class to dark if selectedColorScheme is undefined', () => {
    LocalStorage.get.mockReturnValue(undefined);
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should set documentElement style to dark if selectedColorScheme is dark', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });

  it('should set documentElement style to dark if selectedColorScheme is auto and isOSOnDarkMode is true', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is auto and isOSOnDarkMode is false', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(false);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: light;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is light', () => {
    LocalStorage.get.mockReturnValue('light');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: light;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is undefined', () => {
    LocalStorage.get.mockReturnValue(undefined);
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });
});

// A escolha de quem usa tem de VIAJAR entre aparelhos. Antes ela vivia so no
// `localStorage`, que e de um navegador so: escolher escuro no computador e
// abrir o sistema no celular mostrava claro, como se nada tivesse sido
// escolhido. Agora ela vem do usuario (`ui_settings`) e o `localStorage` fica
// como o que a tela de LOGIN tem para ler - ali ainda nao existe usuario.
describe('a precedencia do tema', () => {
  it('prefers the user choice over what this browser stored', () => {
    LocalStorage.get.mockReturnValue('light');
    setUserColorScheme('dark');

    expect(preferredColorScheme()).toBe('dark');
    expect(setColorTheme(false)).toBe(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('falls back to this browser when the user has no choice', () => {
    LocalStorage.get.mockReturnValue('dark');

    expect(preferredColorScheme()).toBe('dark');
    expect(setColorTheme(false)).toBe(true);
  });

  it('falls back to auto when nobody chose anything', () => {
    LocalStorage.get.mockReturnValue(undefined);

    expect(preferredColorScheme()).toBe('auto');
  });

  // Valor estranho vindo do servidor nao pode virar tema: `auto` e a saida.
  it('ignores a scheme it does not know', () => {
    LocalStorage.get.mockReturnValue(undefined);
    setUserColorScheme('rosa-choque');

    expect(preferredColorScheme()).toBe('auto');
  });

  // A escolha do usuario manda ate no `auto`: quem pediu `auto` volta a seguir o
  // aparelho, mesmo que este navegador tenha `dark` guardado de antes.
  it('lets the user go back to following the device', () => {
    LocalStorage.get.mockReturnValue('dark');
    setUserColorScheme('auto');

    expect(setColorTheme(false)).toBe(false);
    expect(document.body.classList.contains('dark')).toBe(false);
  });
});

// A tela de login estiliza a partir da RAIZ, e o painel a partir do `body`. A
// raiz tambem e o que pinta o fundo antes de qualquer componente montar - sem a
// classe nela, o celular dava um flash branco no carregamento.
describe('onde a classe `dark` e aplicada', () => {
  it('marks both the body and the document root', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(false);

    expect(document.body.classList.contains('dark')).toBe(true);
    expect(document.documentElement.classList.contains('dark')).toBe(true);
  });

  it('clears both when the theme is light', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(false);
    LocalStorage.get.mockReturnValue('light');
    setColorTheme(true);

    expect(document.body.classList.contains('dark')).toBe(false);
    expect(document.documentElement.classList.contains('dark')).toBe(false);
  });
});

describe('storeColorScheme', () => {
  it('writes the choice to this browser', () => {
    storeColorScheme('dark');

    expect(LocalStorage.set).toHaveBeenCalledWith('color_scheme', 'dark');
  });
});

describe('applyColorScheme', () => {
  it('reads the device on its own', () => {
    LocalStorage.get.mockReturnValue('auto');
    const matchMedia = vi.fn(() => ({ matches: true }));
    vi.stubGlobal('matchMedia', matchMedia);

    expect(applyColorScheme()).toBe(true);
    expect(isOSOnDarkMode()).toBe(true);

    vi.unstubAllGlobals();
  });
});
