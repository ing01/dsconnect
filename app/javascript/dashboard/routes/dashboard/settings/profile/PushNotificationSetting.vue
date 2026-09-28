<script setup>
/**
 * A preferência de notificação push.
 *
 * Duas coisas diferentes viviam num botão só:
 *
 *  - **Quero receber push** — decisão da pessoa, e vale para ela em qualquer
 *    lugar onde entrar.
 *  - **Este navegador está inscrito** — fato técnico, de um aparelho só.
 *
 * O botão antigo mostrava apenas o segundo: lia `pushManager.getSubscription()`
 * e nada era gravado no servidor. Quem ativava no computador do trabalho e
 * entrava de casa via "desligado", como se nunca tivesse decidido nada.
 *
 * Agora a decisão vai para `ui_settings` do usuário, que viaja junto no login.
 * O que resta por aparelho é só a permissão do navegador - e, quando ela falta,
 * a tela pede só isso, em vez de perguntar de novo se a pessoa quer receber.
 */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  hasPushPermissions,
  requestPushPermissions,
  verifyServiceWorkerExistence,
} from 'dashboard/helper/pushHelper.js';
import Button from 'dashboard/components-next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

// O navegador sabe fazer push? Sem isso não há o que oferecer.
const temSuporte = computed(() => 'Notification' in window);

// A decisão gravada no usuário - é ela que atravessa os aparelhos.
const preferenciaSalva = computed(() =>
  Boolean(uiSettings.value?.push_notifications_enabled)
);

// O que está no botão agora. Só vira decisão depois de Salvar.
const preferencia = ref(false);
const isSaving = ref(false);
// Este aparelho, especificamente.
const inscritoAqui = ref(false);

const temMudanca = computed(() => preferencia.value !== preferenciaSalva.value);

// Decidiu receber, mas ESTE navegador ainda não liberou. É o caso de quem
// acabou de entrar de outro aparelho: falta um clique, não uma decisão.
const faltaLiberarNavegador = computed(
  () => preferenciaSalva.value && !inscritoAqui.value && temSuporte.value
);

const lerInscricaoDoNavegador = () => {
  if (!hasPushPermissions()) {
    inscritoAqui.value = false;
    return;
  }
  verifyServiceWorkerExistence(registration =>
    registration.pushManager
      .getSubscription()
      .then(subscription => {
        inscritoAqui.value = Boolean(subscription);
      })
      .catch(() => {
        inscritoAqui.value = false;
      })
  );
};

const cancelarInscricaoDoNavegador = () =>
  verifyServiceWorkerExistence(registration =>
    registration.pushManager
      .getSubscription()
      .then(subscription => (subscription ? subscription.unsubscribe() : null))
      .finally(() => {
        inscritoAqui.value = false;
      })
      .catch(() => {})
  );

const ativarNesteNavegador = () => {
  requestPushPermissions({
    onSuccess: () => {
      inscritoAqui.value = true;
    },
  });
};

const salvar = async () => {
  if (isSaving.value || !temMudanca.value) return;

  isSaving.value = true;
  const querReceber = preferencia.value;
  try {
    await updateUISettings({ push_notifications_enabled: querReceber });

    // Ligar a preferência já pede a permissão aqui: quem acabou de decidir
    // que quer receber não deve precisar de um segundo clique no mesmo lugar.
    if (querReceber) ativarNesteNavegador();
    else cancelarInscricaoDoNavegador();

    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_SUCCESS'));
  } catch {
    preferencia.value = preferenciaSalva.value;
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

// As preferências chegam depois do primeiro render (vêm com o usuário), então
// o botão nasce refletindo o que foi carregado, e não `false`.
watch(preferenciaSalva, valor => {
  preferencia.value = valor;
});

onMounted(() => {
  preferencia.value = preferenciaSalva.value;
  lerInscricaoDoNavegador();
});
</script>

<template>
  <div v-if="temSuporte" class="flex flex-col gap-2">
    <div
      class="flex flex-wrap items-center justify-between w-full gap-3 p-4 border border-solid border-n-weak rounded-xl"
    >
      <div class="flex flex-row items-center gap-2 min-w-0">
        <fluent-icon
          icon="alert"
          class="flex-shrink-0 text-n-slate-12"
          size="18"
        />
        <span class="text-body-main text-n-slate-12">
          {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.PUSH_PREFERENCE') }}
        </span>
      </div>

      <div class="flex items-center flex-shrink-0 gap-3">
        <!-- O botão de salvar só aparece quando há o que salvar: um botão
             permanentemente clicável não diz se a mudança ficou gravada. -->
        <Button
          v-if="temMudanca"
          size="sm"
          :label="$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.SAVE')"
          :is-loading="isSaving"
          @click="salvar"
        />
        <ToggleSwitch v-model="preferencia" />
      </div>
    </div>

    <!-- Preferência ligada, navegador ainda não liberado. Pede só a permissão
         - a decisão já foi tomada em outro aparelho. -->
    <div
      v-if="faltaLiberarNavegador"
      class="flex flex-wrap items-center justify-between w-full gap-3 px-4 py-3 border border-dashed border-n-amber-8 rounded-xl"
    >
      <span class="text-sm text-n-slate-11">
        {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_PENDING') }}
      </span>
      <Button
        size="sm"
        faded
        slate
        :label="$t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_ENABLE')"
        @click="ativarNesteNavegador"
      />
    </div>

    <span
      v-else-if="preferenciaSalva && inscritoAqui"
      class="px-1 text-sm text-n-slate-10"
    >
      {{ $t('PROFILE_SETTINGS.FORM.NOTIFICATIONS.BROWSER_READY') }}
    </span>
  </div>
</template>
