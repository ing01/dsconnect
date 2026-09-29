import { useAppearanceHotKeys } from '../useAppearanceHotKeys';
import { useI18n } from 'vue-i18n';
import {
  applyColorScheme,
  setUserColorScheme,
  storeColorScheme,
} from 'dashboard/helper/themeHelper.js';

// A escolha de tema passou a ser gravada tambem NO USUARIO, para viajar entre
// aparelhos: quem escolhia escuro no computador abria o sistema no celular e via
// claro, porque `localStorage` e de um navegador so.
const updateUISettings = vi.fn(() => Promise.resolve());

vi.mock('vue-i18n');
vi.mock('dashboard/helper/themeHelper.js');
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings }),
}));

describe('useAppearanceHotKeys', () => {
  beforeEach(() => {
    useI18n.mockReturnValue({
      t: vi.fn(key => key),
    });

    window.matchMedia = vi.fn().mockReturnValue({ matches: false });
    updateUISettings.mockClear();
  });

  it('should return goToAppearanceHotKeys computed property', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    expect(goToAppearanceHotKeys.value).toBeDefined();
  });

  it('should have the correct number of appearance options', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    expect(goToAppearanceHotKeys.value.length).toBe(4); // 1 parent + 3 theme options
  });

  it('should have the correct parent option', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const parentOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'appearance_settings'
    );
    expect(parentOption).toBeDefined();
    expect(parentOption.children.length).toBe(3);
  });

  it('should have the correct theme options', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const themeOptions = goToAppearanceHotKeys.value.filter(
      option => option.parent === 'appearance_settings'
    );
    expect(themeOptions.length).toBe(3);
    expect(themeOptions.map(option => option.id)).toEqual([
      'light',
      'dark',
      'auto',
    ]);
  });

  it('should call setAppearance when a theme option is selected', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const lightThemeOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'light'
    );

    lightThemeOption.handler();

    expect(storeColorScheme).toHaveBeenCalledWith('light');
    expect(setUserColorScheme).toHaveBeenCalledWith('light');
    expect(applyColorScheme).toHaveBeenCalled();
  });

  // O que faz o celular abrir no mesmo tema do computador.
  it('saves the choice on the user, so it travels between devices', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();

    goToAppearanceHotKeys.value.find(option => option.id === 'dark').handler();

    expect(updateUISettings).toHaveBeenCalledWith({ color_scheme: 'dark' });
  });

  // E o `localStorage` continua sendo gravado porque a tela de LOGIN nao tem
  // usuario de quem herdar preferencia - ele e tudo o que ela tem para ler.
  it('keeps it in this browser as well, for the login screen', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();

    goToAppearanceHotKeys.value.find(option => option.id === 'dark').handler();

    expect(storeColorScheme).toHaveBeenCalledWith('dark');
  });

  it('should handle system dark mode preference', () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: true });

    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const autoThemeOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'auto'
    );

    autoThemeOption.handler();

    expect(storeColorScheme).toHaveBeenCalledWith('auto');
    expect(updateUISettings).toHaveBeenCalledWith({ color_scheme: 'auto' });
    expect(applyColorScheme).toHaveBeenCalled();
  });
});
