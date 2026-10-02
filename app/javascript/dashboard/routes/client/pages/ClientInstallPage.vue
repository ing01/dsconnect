<script setup>
/**
 * Link publico de instalacao do Portal do Cliente - pensado para ser mandado
 * pronto (WhatsApp, e-mail) para alguem que ainda nem tem sessao: a pessoa
 * abre o link, toca em instalar, e so depois entra com o acesso dela. Por
 * isso fica FORA do ClientLayout e de `CLIENT_PUBLIC_PATHS` (ver
 * client.routes.js) - roda sem contato logado, igual a tela de nova senha.
 */
import { useI18n } from 'vue-i18n';
import { useAppInstallPrompt } from 'dashboard/composables/useAppInstallPrompt';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n({ useScope: 'global' });

const { isIosSafari, isStandaloneAlready, isInstallable, instalarApp } =
  useAppInstallPrompt();

const onInstallClick = async () => {
  const installed = await instalarApp();
  if (!installed && isIosSafari) {
    useAlert(t('CLIENT_AREA.INSTALL_APP_IOS_HINT'));
  }
};

const irParaOPortal = () => {
  window.location.assign('/app/login');
};
</script>

<template>
  <div class="flex items-center justify-center w-full min-h-screen p-6 bg-n-background">
    <div class="flex flex-col items-center max-w-sm gap-4 text-center">
      <div class="flex items-center justify-center rounded-2xl size-16 bg-n-brand/10">
        <Icon icon="i-lucide-download" class="text-n-brand size-8" />
      </div>

      <h1 class="m-0 text-xl font-semibold text-n-slate-12">
        {{ t('CLIENT_AREA.INSTALL_PAGE.TITLE') }}
      </h1>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.INSTALL_PAGE.DESCRIPTION') }}
      </p>

      <p v-if="isStandaloneAlready" class="text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.INSTALL_PAGE.ALREADY_INSTALLED') }}
      </p>

      <Button
        v-else-if="isInstallable"
        icon="i-lucide-download"
        :label="t('CLIENT_AREA.INSTALL_APP')"
        @click="onInstallClick"
      />

      <p v-else class="text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.INSTALL_PAGE.NOT_READY_YET') }}
      </p>

      <button class="mt-2 text-sm text-n-brand" @click="irParaOPortal">
        {{ t('CLIENT_AREA.INSTALL_PAGE.GO_TO_LOGIN') }}
      </button>
    </div>
  </div>
</template>
