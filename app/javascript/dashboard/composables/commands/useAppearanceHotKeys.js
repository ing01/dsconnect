import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  ICON_APPEARANCE,
  ICON_LIGHT_MODE,
  ICON_DARK_MODE,
  ICON_SYSTEM_MODE,
} from 'dashboard/helper/commandbar/icons';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  applyColorScheme,
  setUserColorScheme,
  storeColorScheme,
} from 'dashboard/helper/themeHelper.js';

const getThemeOptions = t => [
  {
    key: 'light',
    label: t('COMMAND_BAR.COMMANDS.LIGHT_MODE'),
    icon: ICON_LIGHT_MODE,
  },
  {
    key: 'dark',
    label: t('COMMAND_BAR.COMMANDS.DARK_MODE'),
    icon: ICON_DARK_MODE,
  },
  {
    key: 'auto',
    label: t('COMMAND_BAR.COMMANDS.SYSTEM_MODE'),
    icon: ICON_SYSTEM_MODE,
  },
];

export function useAppearanceHotKeys() {
  const { t } = useI18n();
  const { updateUISettings } = useUISettings();

  // A escolha vai para os DOIS lugares, e cada um serve a uma coisa:
  //
  //  - `ui_settings`, no usuario, e o que viaja entre aparelhos - e o que faz o
  //    celular abrir no mesmo tema do computador;
  //  - `localStorage`, neste navegador, e o que a tela de LOGIN tem para ler:
  //    ali ainda nao existe usuario de quem herdar preferencia.
  //
  // A tela muda antes de o servidor responder: o tema e resposta a um clique, e
  // esperar a rede para pintar deixaria o clique sem efeito visivel.
  const setAppearance = async theme => {
    setUserColorScheme(theme);
    storeColorScheme(theme);
    applyColorScheme();

    await updateUISettings({ color_scheme: theme });
  };

  const themeOptions = computed(() => getThemeOptions(t));

  const goToAppearanceHotKeys = computed(() => {
    const options = themeOptions.value.map(theme => ({
      id: theme.key,
      title: theme.label,
      parent: 'appearance_settings',
      section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
      icon: theme.icon,
      handler: () => {
        setAppearance(theme.key);
      },
    }));
    return [
      {
        id: 'appearance_settings',
        title: t('COMMAND_BAR.COMMANDS.CHANGE_APPEARANCE'),
        section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
        icon: ICON_APPEARANCE,
        children: options.map(option => option.id),
      },
      ...options,
    ];
  });

  return {
    goToAppearanceHotKeys,
  };
}
