<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';

import WithLabel from 'v3/components/Form/WithLabel.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { currentAccount, updateAccount } = useAccount();

// Faixas 1-3 da configuracao "IA resolve sozinha" - escala fixa, nao lida de
// lugar nenhum dinamico.
const LEVELS = [1, 2, 3];
const PRIORITY_OPTIONS = ['baixa', 'media', 'alta'];

const whatsappFlowEnabled = ref(true);
const aiResolveLevels = ref([1, 2]);
const defaultPriorityOnAiFailure = ref('baixa');
const openTicketWindowDays = ref(null);
const level3to5TeamId = ref(null);
const defaultQueueId = ref(null);
const queueLowId = ref(null);
const queueHighId = ref(null);
const supportPhoneNumber = ref('');
const whatsappAutomationTestModeNumber = ref('');
const isSubmitting = ref(false);

const teams = computed(() => getters['teams/getTeams'].value);
const queues = computed(() => getters['queues/getQueues'].value);

onBeforeMount(() => {
  store.dispatch('teams/get');
  store.dispatch('queues/get');
});

watch(
  currentAccount,
  () => {
    const settings = currentAccount.value?.settings || {};
    whatsappFlowEnabled.value = settings.helpdesk_whatsapp_flow_enabled ?? true;
    aiResolveLevels.value = settings.helpdesk_ai_resolve_levels?.length
      ? settings.helpdesk_ai_resolve_levels
      : [1, 2];
    defaultPriorityOnAiFailure.value =
      settings.helpdesk_default_priority_on_ai_failure || 'baixa';
    openTicketWindowDays.value =
      settings.helpdesk_open_ticket_window_days ?? null;
    level3to5TeamId.value = settings.helpdesk_level_3to5_team_id ?? null;
    defaultQueueId.value = settings.helpdesk_default_queue_id ?? null;
    queueLowId.value = settings.helpdesk_queue_low_id ?? null;
    queueHighId.value = settings.helpdesk_queue_high_id ?? null;
    supportPhoneNumber.value = settings.helpdesk_support_phone_number || '';
    whatsappAutomationTestModeNumber.value =
      settings.whatsapp_automation_test_mode_number || '';
  },
  { deep: true, immediate: true }
);

const toggleLevel = level => {
  aiResolveLevels.value = aiResolveLevels.value.includes(level)
    ? aiResolveLevels.value.filter(item => item !== level)
    : [...aiResolveLevels.value, level].sort((a, b) => a - b);
};

// Mesmo formato que o cadastro de contato usa pro telefone: + seguido de
// 2 a 15 digitos (E.164). Vazio e valido - e' como se a trava estivesse
// desligada.
const testModeNumberInvalid = computed(() => {
  const value = whatsappAutomationTestModeNumber.value.trim();
  return value.length > 0 && !/^\+[1-9]\d{1,14}$/.test(value);
});

const saveSettings = async () => {
  if (testModeNumberInvalid.value) {
    useAlert(t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.INVALID_NUMBER'));
    return false;
  }

  try {
    await updateAccount(
      {
        helpdesk_whatsapp_flow_enabled: whatsappFlowEnabled.value,
        helpdesk_ai_resolve_levels: aiResolveLevels.value,
        helpdesk_default_priority_on_ai_failure:
          defaultPriorityOnAiFailure.value,
        helpdesk_open_ticket_window_days: openTicketWindowDays.value || null,
        helpdesk_level_3to5_team_id: level3to5TeamId.value || null,
        helpdesk_default_queue_id: defaultQueueId.value || null,
        helpdesk_queue_low_id: queueLowId.value || null,
        helpdesk_queue_high_id: queueHighId.value || null,
        helpdesk_support_phone_number: supportPhoneNumber.value.trim() || null,
        whatsapp_automation_test_mode_number:
          whatsappAutomationTestModeNumber.value.trim() || null,
      },
      { silent: true }
    );
    return true;
  } catch (error) {
    return false;
  }
};

const handleSubmit = async () => {
  isSubmitting.value = true;
  const success = await saveSettings();
  useAlert(
    t(
      success
        ? 'TICKET.SETTINGS.AUTOMATION.API.SUCCESS'
        : 'TICKET.SETTINGS.AUTOMATION.API.ERROR'
    )
  );
  isSubmitting.value = false;
};

</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.AUTOMATION.TITLE')"
        :description="t('TICKET.SETTINGS.AUTOMATION.DESCRIPTION')"
      />
    </template>

    <template #body>
      <p class="flex items-center gap-2 mb-0 text-sm text-n-slate-11">
        <Icon icon="i-lucide-info" class="shrink-0 size-4" />
        {{ t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.MOVED_NOTICE') }}
        <router-link
          :to="{ name: 'ticket_distribution_settings' }"
          class="underline hover:no-underline"
        >
          {{ t('TICKET.SETTINGS.DISTRIBUTION.TITLE') }}
        </router-link>
      </p>
      <form
        class="flex flex-col w-full max-w-2xl gap-5"
        @submit.prevent="handleSubmit"
      >
        <div
          class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
        >
          <div class="flex items-center justify-between gap-4 px-5 py-4">
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{ t('TICKET.SETTINGS.AUTOMATION.WHATSAPP_FLOW.LABEL') }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{ t('TICKET.SETTINGS.AUTOMATION.WHATSAPP_FLOW.HELP') }}
              </p>
            </div>
            <Switch v-model="whatsappFlowEnabled" />
          </div>

          <!-- A distribuicao automatica do Portal (liga/desliga, limite e
               excecao) foi consolidada em Configuracoes > Tickets >
               Distribuicao Automatica (pedido da Ingrid, 2026-11-12). -->

          <div class="flex flex-col gap-2 px-5 py-4">
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{ t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.TITLE') }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{ t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.DESCRIPTION') }}
              </p>
            </div>
            <input
              v-model="whatsappAutomationTestModeNumber"
              type="text"
              class="mb-0 max-w-xs"
              :placeholder="
                t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.PLACEHOLDER')
              "
            />
            <p v-if="testModeNumberInvalid" class="mb-0 text-xs text-n-ruby-11">
              {{ t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.INVALID_NUMBER') }}
            </p>
            <div
              v-else-if="whatsappAutomationTestModeNumber.trim()"
              class="py-2 px-3 mt-1 bg-n-amber-3 outline-n-amber-4 text-n-amber-11 outline outline-1 -outline-offset-1 rounded-xl"
            >
              <p class="mb-0 text-body-para">
                {{
                  t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.ACTIVE_WARNING', {
                    number: whatsappAutomationTestModeNumber.trim(),
                  })
                }}
              </p>
            </div>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.AI_RESOLVE_LEVELS.LABEL')"
              :help-message="
                t('TICKET.SETTINGS.AUTOMATION.AI_RESOLVE_LEVELS.HELP')
              "
            >
              <div class="flex flex-wrap gap-4 pt-1">
                <label
                  v-for="level in LEVELS"
                  :key="level"
                  class="flex items-center gap-2 text-sm text-n-slate-12"
                >
                  <input
                    type="checkbox"
                    class="m-0"
                    :checked="aiResolveLevels.includes(level)"
                    @change="toggleLevel(level)"
                  />
                  {{ t('TICKET.SETTINGS.AUTOMATION.LEVEL_LABEL', { level }) }}
                </label>
              </div>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.DEFAULT_PRIORITY.LABEL')"
              :help-message="
                t('TICKET.SETTINGS.AUTOMATION.DEFAULT_PRIORITY.HELP')
              "
            >
              <select v-model="defaultPriorityOnAiFailure" class="mb-0">
                <option
                  v-for="option in PRIORITY_OPTIONS"
                  :key="option"
                  :value="option"
                >
                  {{
                    t(
                      `TICKET.SETTINGS.AUTOMATION.PRIORITY_LABEL.${option.toUpperCase()}`
                    )
                  }}
                </option>
              </select>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.OPEN_TICKET_WINDOW.LABEL')"
              :help-message="
                t('TICKET.SETTINGS.AUTOMATION.OPEN_TICKET_WINDOW.HELP')
              "
            >
              <input
                v-model.number="openTicketWindowDays"
                type="number"
                min="1"
                class="mb-0"
                :placeholder="
                  t('TICKET.SETTINGS.AUTOMATION.OPEN_TICKET_WINDOW.PLACEHOLDER')
                "
              />
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.LEVEL_3TO5_TEAM.LABEL')"
              :help-message="
                t('TICKET.SETTINGS.AUTOMATION.LEVEL_3TO5_TEAM.HELP')
              "
            >
              <select v-model="level3to5TeamId" class="mb-0">
                <option :value="null">
                  {{ t('TICKET.SETTINGS.AUTOMATION.LEVEL_3TO5_TEAM.NONE') }}
                </option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ formatMesaName(team.name) }}
                </option>
              </select>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.QUEUE_LOW.LABEL')"
              :help-message="t('TICKET.SETTINGS.AUTOMATION.QUEUE_LOW.HELP')"
            >
              <select v-model="queueLowId" class="mb-0">
                <option :value="null">
                  {{ t('TICKET.SETTINGS.AUTOMATION.DEFAULT_QUEUE.NONE') }}
                </option>
                <option
                  v-for="queue in queues"
                  :key="queue.id"
                  :value="queue.id"
                >
                  {{ queue.name }}
                </option>
              </select>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.QUEUE_HIGH.LABEL')"
              :help-message="t('TICKET.SETTINGS.AUTOMATION.QUEUE_HIGH.HELP')"
            >
              <select v-model="queueHighId" class="mb-0">
                <option :value="null">
                  {{ t('TICKET.SETTINGS.AUTOMATION.DEFAULT_QUEUE.NONE') }}
                </option>
                <option
                  v-for="queue in queues"
                  :key="queue.id"
                  :value="queue.id"
                >
                  {{ queue.name }}
                </option>
              </select>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.SUPPORT_PHONE.LABEL')"
              :help-message="t('TICKET.SETTINGS.AUTOMATION.SUPPORT_PHONE.HELP')"
            >
              <input
                v-model="supportPhoneNumber"
                type="text"
                class="mb-0 max-w-xs"
                :placeholder="
                  t('TICKET.SETTINGS.AUTOMATION.SUPPORT_PHONE.PLACEHOLDER')
                "
              />
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="t('TICKET.SETTINGS.AUTOMATION.DEFAULT_QUEUE.LABEL')"
              :help-message="t('TICKET.SETTINGS.AUTOMATION.DEFAULT_QUEUE.HELP')"
            >
              <select v-model="defaultQueueId" class="mb-0">
                <option :value="null">
                  {{ t('TICKET.SETTINGS.AUTOMATION.DEFAULT_QUEUE.NONE') }}
                </option>
                <option
                  v-for="queue in queues"
                  :key="queue.id"
                  :value="queue.id"
                >
                  {{ queue.name }}
                </option>
              </select>
            </WithLabel>
          </div>
        </div>

        <div class="flex justify-end">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :label="t('TICKET.SETTINGS.AUTOMATION.SAVE')"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>
