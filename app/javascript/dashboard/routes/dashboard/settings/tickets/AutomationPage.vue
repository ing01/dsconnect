<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import CompaniesAPI from 'dashboard/api/companies';

import WithLabel from 'v3/components/Form/WithLabel.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { currentAccount, updateAccount } = useAccount();

// Niveis do cliente que existem hoje (Company#client_level, 1-3: Baixa/
// Media/Alta) - nao lido de lugar nenhum dinamico porque a escala em si e
// fixa no backend.
const LEVELS = [1, 2, 3];
const PRIORITY_OPTIONS = ['baixa', 'media', 'alta'];
// Mesmo texto padrao de Account::DEFAULT_WHATSAPP_CSAT_SURVEY_MESSAGE - so
// pra pre-preencher o campo com algo editavel em vez de vazio antes do
// primeiro salvamento; o backend tem o mesmo default como rede de seguranca.
const DEFAULT_CSAT_SURVEY_MESSAGE =
  'Como você avalia nosso atendimento? Responda com um número de 1 a 5, sendo 1 (péssimo) e 5 (ótimo).';

const whatsappFlowEnabled = ref(true);
const whatsappAutoAssignmentEnabled = ref(true);
const whatsappAutoAssignmentMaxOpenChats = ref(null);
const whatsappAutoAssignmentExcludedAgentIds = ref([]);
const whatsappCsatSurveyEnabled = ref(false);
const whatsappCsatSurveyMessage = ref(DEFAULT_CSAT_SURVEY_MESSAGE);
const aiResolveLevels = ref([1, 2]);
const defaultPriorityOnAiFailure = ref('baixa');
const openTicketWindowDays = ref(null);
const level3to5TeamId = ref(null);
const defaultQueueId = ref(null);
const queueLowId = ref(null);
const queueHighId = ref(null);
const priorityThresholdMediumMin = ref(null);
const priorityThresholdHighMin = ref(null);
const whatsappAutomationTestModeNumber = ref('');
const isSubmitting = ref(false);
const isRecalculating = ref(false);

const teams = computed(() => getters['teams/getTeams'].value);
const queues = computed(() => getters['queues/getQueues'].value);
const agents = computed(() => getters['agents/getAgents'].value);

onBeforeMount(() => {
  store.dispatch('teams/get');
  store.dispatch('queues/get');
  store.dispatch('agents/get');
});

watch(
  currentAccount,
  () => {
    const settings = currentAccount.value?.settings || {};
    whatsappFlowEnabled.value =
      settings.helpdesk_whatsapp_flow_enabled ?? true;
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
    priorityThresholdMediumMin.value =
      settings.priority_threshold_medium_min ?? null;
    priorityThresholdHighMin.value =
      settings.priority_threshold_high_min ?? null;
    whatsappAutomationTestModeNumber.value =
      settings.whatsapp_automation_test_mode_number || '';
    whatsappAutoAssignmentEnabled.value =
      settings.whatsapp_auto_assignment_enabled ?? true;
    whatsappAutoAssignmentMaxOpenChats.value =
      settings.whatsapp_auto_assignment_max_open_chats ?? null;
    whatsappAutoAssignmentExcludedAgentIds.value =
      settings.whatsapp_auto_assignment_excluded_agent_ids || [];
    whatsappCsatSurveyEnabled.value =
      settings.whatsapp_csat_survey_enabled ?? false;
    whatsappCsatSurveyMessage.value =
      settings.whatsapp_csat_survey_message || DEFAULT_CSAT_SURVEY_MESSAGE;
  },
  { deep: true, immediate: true }
);

const toggleLevel = level => {
  aiResolveLevels.value = aiResolveLevels.value.includes(level)
    ? aiResolveLevels.value.filter(item => item !== level)
    : [...aiResolveLevels.value, level].sort((a, b) => a - b);
};

const toggleExcludedAgent = agentId => {
  whatsappAutoAssignmentExcludedAgentIds.value =
    whatsappAutoAssignmentExcludedAgentIds.value.includes(agentId)
      ? whatsappAutoAssignmentExcludedAgentIds.value.filter(
          id => id !== agentId
        )
      : [...whatsappAutoAssignmentExcludedAgentIds.value, agentId];
};

const priorityThresholdsInvalid = computed(() => {
  const medium = priorityThresholdMediumMin.value;
  const high = priorityThresholdHighMin.value;
  return medium != null && high != null && Number(high) <= Number(medium);
});

// Mesmo formato que o cadastro de contato usa pro telefone: + seguido de
// 2 a 15 digitos (E.164). Vazio e valido - e' como se a trava estivesse
// desligada.
const testModeNumberInvalid = computed(() => {
  const value = whatsappAutomationTestModeNumber.value.trim();
  return value.length > 0 && !/^\+[1-9]\d{1,14}$/.test(value);
});

const csatSurveyMessageInvalid = computed(
  () =>
    whatsappCsatSurveyEnabled.value && !whatsappCsatSurveyMessage.value.trim()
);

// Compartilhado pelo botao "Salvar" e pelo "Recalcular agora" - o recalculo
// sempre salva primeiro, senao rodaria com os limiares antigos ainda
// gravados no banco.
const saveSettings = async () => {
  if (priorityThresholdsInvalid.value) {
    useAlert(t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.INVALID_RANGE'));
    return false;
  }
  if (testModeNumberInvalid.value) {
    useAlert(t('TICKET.SETTINGS.AUTOMATION.TEST_MODE.INVALID_NUMBER'));
    return false;
  }
  if (csatSurveyMessageInvalid.value) {
    useAlert(t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.MESSAGE_REQUIRED'));
    return false;
  }

  try {
    await updateAccount(
      {
        helpdesk_whatsapp_flow_enabled: whatsappFlowEnabled.value,
        helpdesk_ai_resolve_levels: aiResolveLevels.value,
        helpdesk_default_priority_on_ai_failure: defaultPriorityOnAiFailure.value,
        helpdesk_open_ticket_window_days: openTicketWindowDays.value || null,
        helpdesk_level_3to5_team_id: level3to5TeamId.value || null,
        helpdesk_default_queue_id: defaultQueueId.value || null,
        helpdesk_queue_low_id: queueLowId.value || null,
        helpdesk_queue_high_id: queueHighId.value || null,
        priority_threshold_medium_min: priorityThresholdMediumMin.value || null,
        priority_threshold_high_min: priorityThresholdHighMin.value || null,
        whatsapp_automation_test_mode_number:
          whatsappAutomationTestModeNumber.value.trim() || null,
        whatsapp_auto_assignment_enabled: whatsappAutoAssignmentEnabled.value,
        whatsapp_auto_assignment_max_open_chats:
          whatsappAutoAssignmentMaxOpenChats.value || null,
        whatsapp_auto_assignment_excluded_agent_ids:
          whatsappAutoAssignmentExcludedAgentIds.value,
        whatsapp_csat_survey_enabled: whatsappCsatSurveyEnabled.value,
        whatsapp_csat_survey_message: whatsappCsatSurveyMessage.value.trim() || null,
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

const handleRecalculatePriorities = async () => {
  isRecalculating.value = true;
  try {
    const saved = await saveSettings();
    if (!saved) {
      useAlert(t('TICKET.SETTINGS.AUTOMATION.API.ERROR'));
      return;
    }

    await CompaniesAPI.recalculatePriorities();
    useAlert(
      t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.RECALCULATE_STARTED')
    );
  } catch (error) {
    useAlert(
      t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.RECALCULATE_ERROR')
    );
  } finally {
    isRecalculating.value = false;
  }
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

          <div class="flex flex-col gap-3 px-5 py-4">
            <div class="flex items-center justify-between gap-4">
              <div class="flex flex-col gap-1">
                <h3 class="text-heading-2 text-n-slate-12">
                  {{ t('TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.TITLE') }}
                </h3>
                <p class="mb-0 text-body-para text-n-slate-11">
                  {{
                    t('TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.DESCRIPTION')
                  }}
                </p>
              </div>
              <Switch v-model="whatsappAutoAssignmentEnabled" />
            </div>

            <template v-if="whatsappAutoAssignmentEnabled">
              <WithLabel
                :label="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.MAX_OPEN_CHATS.LABEL'
                  )
                "
                :help-message="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.MAX_OPEN_CHATS.HELP'
                  )
                "
              >
                <input
                  v-model.number="whatsappAutoAssignmentMaxOpenChats"
                  type="number"
                  min="1"
                  class="mb-0 max-w-xs"
                  :placeholder="
                    t(
                      'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.MAX_OPEN_CHATS.PLACEHOLDER'
                    )
                  "
                />
              </WithLabel>

              <WithLabel
                :label="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.EXCLUDED_AGENTS.LABEL'
                  )
                "
                :help-message="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.EXCLUDED_AGENTS.HELP'
                  )
                "
              >
                <div
                  v-if="agents.length"
                  class="flex flex-col gap-2 pt-1 max-h-48 overflow-y-auto"
                >
                  <label
                    v-for="agent in agents"
                    :key="agent.id"
                    class="flex items-center gap-2 text-sm text-n-slate-12"
                  >
                    <input
                      type="checkbox"
                      class="m-0"
                      :checked="
                        whatsappAutoAssignmentExcludedAgentIds.includes(
                          agent.id
                        )
                      "
                      @change="toggleExcludedAgent(agent.id)"
                    />
                    {{ agent.name }}
                  </label>
                </div>
                <p v-else class="mb-0 text-xs text-n-slate-11">
                  {{
                    t(
                      'TICKET.SETTINGS.AUTOMATION.AUTO_ASSIGNMENT.EXCLUDED_AGENTS.EMPTY'
                    )
                  }}
                </p>
              </WithLabel>
            </template>
          </div>

          <div class="flex flex-col gap-3 px-5 py-4">
            <div class="flex items-center justify-between gap-4">
              <div class="flex flex-col gap-1">
                <h3 class="text-heading-2 text-n-slate-12">
                  {{ t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.TITLE') }}
                </h3>
                <p class="mb-0 text-body-para text-n-slate-11">
                  {{ t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.DESCRIPTION') }}
                </p>
              </div>
              <Switch v-model="whatsappCsatSurveyEnabled" />
            </div>

            <div v-if="whatsappCsatSurveyEnabled" class="flex flex-col gap-1">
              <label class="text-sm text-n-slate-12">
                {{ t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.MESSAGE_LABEL') }}
              </label>
              <textarea
                v-model="whatsappCsatSurveyMessage"
                rows="3"
                class="mb-0"
                :placeholder="
                  t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.MESSAGE_PLACEHOLDER')
                "
              />
              <p
                v-if="csatSurveyMessageInvalid"
                class="mb-0 text-xs text-n-ruby-11"
              >
                {{ t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.MESSAGE_REQUIRED') }}
              </p>
              <p v-else class="mb-0 text-xs text-n-slate-11">
                {{ t('TICKET.SETTINGS.AUTOMATION.CSAT_SURVEY.MESSAGE_HELP') }}
              </p>
            </div>
          </div>

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
            <p
              v-if="testModeNumberInvalid"
              class="mb-0 text-xs text-n-ruby-11"
            >
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
                  {{
                    t('TICKET.SETTINGS.AUTOMATION.LEVEL_LABEL', { level })
                  }}
                </label>
              </div>
            </WithLabel>
          </div>

          <div class="flex flex-col gap-2 px-5 py-4">
            <WithLabel
              :label="
                t('TICKET.SETTINGS.AUTOMATION.DEFAULT_PRIORITY.LABEL')
              "
              :help-message="
                t('TICKET.SETTINGS.AUTOMATION.DEFAULT_PRIORITY.HELP')
              "
            >
              <select v-model="defaultPriorityOnAiFailure" class="mb-0">
                <option v-for="option in PRIORITY_OPTIONS" :key="option" :value="option">
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
              :label="
                t('TICKET.SETTINGS.AUTOMATION.OPEN_TICKET_WINDOW.LABEL')
              "
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
                  t(
                    'TICKET.SETTINGS.AUTOMATION.OPEN_TICKET_WINDOW.PLACEHOLDER'
                  )
                "
              />
            </WithLabel>
          </div>

          <div class="flex flex-col gap-3 px-5 py-4">
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{ t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.TITLE') }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{
                  t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.DESCRIPTION')
                }}
              </p>
            </div>
            <div class="grid w-full gap-4 sm:grid-cols-2">
              <WithLabel
                :label="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.MEDIUM_MIN.LABEL'
                  )
                "
              >
                <input
                  v-model.number="priorityThresholdMediumMin"
                  type="number"
                  min="0"
                  step="0.01"
                  class="mb-0"
                  :placeholder="
                    t(
                      'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.MEDIUM_MIN.PLACEHOLDER'
                    )
                  "
                />
              </WithLabel>
              <WithLabel
                :label="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.HIGH_MIN.LABEL'
                  )
                "
              >
                <input
                  v-model.number="priorityThresholdHighMin"
                  type="number"
                  min="0"
                  step="0.01"
                  class="mb-0"
                  :placeholder="
                    t(
                      'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.HIGH_MIN.PLACEHOLDER'
                    )
                  "
                />
              </WithLabel>
            </div>
            <p v-if="priorityThresholdsInvalid" class="mb-0 text-xs text-n-ruby-11">
              {{ t('TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.INVALID_RANGE') }}
            </p>
            <div class="flex items-center justify-between gap-2">
              <p class="mb-0 text-xs text-n-slate-11">
                {{
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.RECALCULATE_HELP'
                  )
                }}
              </p>
              <NextButton
                type="button"
                slate
                faded
                sm
                :is-loading="isRecalculating"
                :disabled="priorityThresholdsInvalid"
                :label="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PRIORITY_THRESHOLDS.RECALCULATE_BUTTON'
                  )
                "
                @click="handleRecalculatePriorities"
              />
            </div>
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
                <option v-for="queue in queues" :key="queue.id" :value="queue.id">
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
                <option v-for="queue in queues" :key="queue.id" :value="queue.id">
                  {{ queue.name }}
                </option>
              </select>
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
                <option v-for="queue in queues" :key="queue.id" :value="queue.id">
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
