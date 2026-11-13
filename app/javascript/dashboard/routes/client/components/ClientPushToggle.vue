<script setup>
/**
 * O botão de ligar/desligar as notificações do navegador, no cabeçalho da Área
 * do Cliente (só existe na web - o app do celular tem o próprio caminho).
 *
 * Ligar: pede a permissão, e é aí que o navegador mostra o próprio aviso
 * ("Permitir notificações?"). Desligar: o navegador NÃO deixa a página revogar
 * a permissão - o que dá para fazer é cancelar a inscrição deste navegador, e
 * é isso que o botão faz (o servidor para de enviar para cá). Se a permissão
 * está BLOQUEADA no navegador, só a pessoa consegue liberar: o aviso leva ao
 * tutorial.
 *
 * Escondido onde o navegador não suporta push (ex.: iPhone fora do app instalado).
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  clientPushPermission,
  clientPushSupported,
  disableClientPush,
  ensureClientPushSubscribed,
  isClientPushEnabled,
  requestClientPushPermission,
} from 'dashboard/helper/clientPushHelper';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const supported = clientPushSupported();
const enabled = ref(false);
const isBusy = ref(false);

const refresh = () => {
  enabled.value = isClientPushEnabled();
};

const blockedAlert = () =>
  useAlert(t('CLIENT_AREA.PUSH_TOGGLE.BLOCKED'), {
    type: 'link',
    to: '/app/client/tutorials',
    message: t('CLIENT_AREA.PUSH_TOGGLE.SEE_TUTORIAL'),
    duration: 12000,
  });

const toggle = async () => {
  isBusy.value = true;
  try {
    if (enabled.value) {
      await disableClientPush();
      refresh();
      useAlert(t('CLIENT_AREA.PUSH_TOGGLE.DISABLED'));
      return;
    }

    if (clientPushPermission() === 'denied') {
      blockedAlert();
      return;
    }

    const granted = await requestClientPushPermission();
    refresh();
    if (granted) {
      useAlert(t('CLIENT_AREA.PUSH_TOGGLE.ENABLED'));
    } else if (clientPushPermission() === 'denied') {
      blockedAlert();
    } else {
      useAlert(t('CLIENT_AREA.PUSH_TOGGLE.NOT_ENABLED'));
    }
  } finally {
    isBusy.value = false;
  }
};

// Garante a inscricao e manda um aviso de verdade: e' a prova de que as
// notificacoes reais chegam neste aparelho.
const isTesting = ref(false);

const sendTest = async () => {
  isTesting.value = true;
  try {
    await ensureClientPushSubscribed();
    const { data } = await ClientAreaAPI.testPushSubscription();
    useAlert(
      data.devices
        ? t('CLIENT_AREA.PUSH_TOGGLE.TEST_SENT', { count: data.devices })
        : t('CLIENT_AREA.PUSH_TOGGLE.TEST_NO_DEVICE')
    );
  } catch (error) {
    useAlert(t('CLIENT_AREA.PUSH_TOGGLE.TEST_ERROR'));
  } finally {
    isTesting.value = false;
  }
};

const label = computed(() =>
  enabled.value
    ? t('CLIENT_AREA.PUSH_TOGGLE.ON')
    : t('CLIENT_AREA.PUSH_TOGGLE.OFF')
);

onMounted(refresh);
</script>

<template>
  <div v-if="supported" class="flex items-center gap-2">
    <Button
      faded
      size="sm"
      :slate="!enabled"
      :blue="enabled"
      :icon="enabled ? 'i-lucide-bell-ring' : 'i-lucide-bell-off'"
      :label="label"
      :title="
        enabled
          ? t('CLIENT_AREA.PUSH_TOGGLE.TITLE_ON')
          : t('CLIENT_AREA.PUSH_TOGGLE.TITLE_OFF')
      "
      :is-loading="isBusy"
      :aria-pressed="enabled"
      data-testid="client-push-toggle"
      @click="toggle"
    />
    <Button
      v-if="enabled"
      faded
      slate
      size="sm"
      icon="i-lucide-send"
      :label="t('CLIENT_AREA.PUSH_TOGGLE.TEST')"
      :title="t('CLIENT_AREA.PUSH_TOGGLE.TEST_TITLE')"
      :is-loading="isTesting"
      data-testid="client-push-test"
      @click="sendTest"
    />
  </div>
</template>
