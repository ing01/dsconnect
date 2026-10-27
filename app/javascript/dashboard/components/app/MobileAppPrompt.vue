<script setup>
/**
 * O convite para baixar o app, mostrado a quem abre o site num celular ou
 * tablet. "Continuar na Web" esconde o aviso e o aparelho lembra a escolha.
 *
 * Nao aparece quando o site ja roda como app instalado (PWA): quem esta dentro
 * do app nao precisa ser convidado a baixa-lo.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  APP_STORE_URL,
  PLAY_STORE_URL,
  isMobileDevice,
} from 'dashboard/helper/appStoreLinks';
import {
  hasDismissedMobileAppPrompt,
  setMobileAppPromptDismissed,
} from 'dashboard/helper/clientSession';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n({ useScope: 'global' });

const isStandalone =
  window.matchMedia('(display-mode: standalone)').matches ||
  window.navigator.standalone === true;

const isVisible = ref(
  isMobileDevice() && !isStandalone && !hasDismissedMobileAppPrompt()
);

const continueOnWeb = () => {
  setMobileAppPromptDismissed();
  isVisible.value = false;
};

const STORE_LINK_CLASS =
  'flex items-center justify-center w-full gap-2 px-4 text-sm font-medium text-white rounded-lg h-11 bg-n-brand hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand';
</script>

<template>
  <div
    v-if="isVisible"
    class="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-n-background"
    role="dialog"
    aria-modal="true"
    :aria-label="t('CLIENT_AREA.MOBILE_APP_PROMPT.TITLE')"
  >
    <div class="flex flex-col items-center w-full max-w-sm gap-4 text-center">
      <div
        class="flex items-center justify-center rounded-2xl size-16 bg-n-brand/10"
      >
        <Icon icon="i-lucide-smartphone" class="size-8 text-n-brand" />
      </div>

      <h1 class="m-0 text-xl font-semibold text-n-slate-12">
        {{ t('CLIENT_AREA.MOBILE_APP_PROMPT.TITLE') }}
      </h1>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.MOBILE_APP_PROMPT.DESCRIPTION') }}
      </p>

      <div class="flex flex-col w-full gap-2">
        <a
          :href="PLAY_STORE_URL"
          target="_blank"
          rel="noopener noreferrer"
          :class="STORE_LINK_CLASS"
        >
          <Icon icon="i-lucide-download" class="size-4" />
          {{ t('CLIENT_AREA.MOBILE_APP_PROMPT.PLAY_STORE') }}
        </a>
        <a
          :href="APP_STORE_URL"
          target="_blank"
          rel="noopener noreferrer"
          :class="STORE_LINK_CLASS"
        >
          <Icon icon="i-lucide-download" class="size-4" />
          {{ t('CLIENT_AREA.MOBILE_APP_PROMPT.APP_STORE') }}
        </a>
      </div>

      <button
        type="button"
        class="mt-2 text-sm font-medium text-n-brand"
        @click="continueOnWeb"
      >
        {{ t('CLIENT_AREA.MOBILE_APP_PROMPT.CONTINUE_WEB') }}
      </button>
    </div>
  </div>
</template>
