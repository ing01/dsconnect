<script setup>
/**
 * O tema do sistema.
 *
 * Ate aqui a unica forma de escolher era a barra de comandos (Ctrl+K), que num
 * celular simplesmente nao existe: nao ha teclado para o atalho, e o tema ficava
 * inalcancavel justamente onde o problema aparecia - o aparelho no claro
 * acendendo o sistema inteiro.
 *
 * A escolha vai para dois lugares, e cada um serve a uma coisa: `ui_settings`, no
 * usuario, e o que VIAJA entre aparelhos; `localStorage`, neste navegador, e o
 * que a tela de LOGIN tem para ler, porque ali ainda nao existe usuario.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  applyColorScheme,
  setUserColorScheme,
  storeColorScheme,
} from 'dashboard/helper/themeHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const OPCOES = [
  { key: 'light', icon: 'i-lucide-sun' },
  { key: 'dark', icon: 'i-lucide-moon' },
  { key: 'auto', icon: 'i-lucide-monitor' },
];

// Sem escolha gravada o sistema segue o aparelho, e e isso que a tela mostra.
const escolhida = computed(() => uiSettings.value?.color_scheme || 'auto');

const escolher = async chave => {
  if (chave === escolhida.value) return;

  // A tela muda antes de o servidor responder: tema e resposta a um toque, e
  // esperar a rede para pintar deixaria o toque sem efeito visivel.
  setUserColorScheme(chave);
  storeColorScheme(chave);
  applyColorScheme();

  try {
    await updateUISettings({ color_scheme: chave });
  } catch {
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-wrap gap-2 min-w-0">
    <button
      v-for="opcao in OPCOES"
      :key="opcao.key"
      type="button"
      class="flex items-center gap-2 px-3 py-2 text-sm border border-solid rounded-lg min-w-0"
      :class="
        escolhida === opcao.key
          ? 'border-n-brand text-n-slate-12 bg-n-alpha-2 font-medium'
          : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-1'
      "
      :aria-pressed="escolhida === opcao.key"
      @click="escolher(opcao.key)"
    >
      <Icon :icon="opcao.icon" class="flex-shrink-0 size-4" />
      {{ t(`PROFILE_SETTINGS.FORM.APPEARANCE.${opcao.key.toUpperCase()}`) }}
    </button>
  </div>
</template>
