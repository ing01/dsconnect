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
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { currentAccount, updateAccount } = useAccount();

const DISTRIBUTION_STRATEGIES = ['manual', 'round_robin', 'least_busy'];

const queues = computed(() => getters['queues/getQueues'].value);
const teams = computed(() => getters['teams/getTeams'].value);
const agents = computed(() => getters['agents/getAgents'].value);
const inboxesList = computed(() => getters['inboxes/getInboxes'].value);

// `Channel::TwilioSms` carrega SMS e WhatsApp no mesmo tipo - so' o `medium`
// separa os dois (mesmo criterio de `useInbox.js`, so' que aqui direto sobre
// a lista crua de inboxes, sem o composable - que e' pensado pra UMA inbox
// reativa, nao pra filtrar uma lista).
const isWhatsAppInbox = inbox =>
  inbox.channel_type === 'Channel::Whatsapp' ||
  (inbox.channel_type === 'Channel::TwilioSms' && inbox.medium === 'whatsapp');

const whatsappInboxes = computed(() =>
  inboxesList.value.filter(isWhatsAppInbox)
);

const teamNameById = id => {
  const team = teams.value.find(item => item.id === id);
  return team ? formatMesaName(team.name) : '';
};

const isUpdatingQueueId = ref(null);
const updateQueueStrategy = async (queue, strategy) => {
  if (strategy === queue.distribution_strategy) return;

  isUpdatingQueueId.value = queue.id;
  try {
    await store.dispatch('queues/update', {
      id: queue.id,
      distribution_strategy: strategy,
    });
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.DISTRIBUTION.QUEUES.API.ERROR'));
  } finally {
    isUpdatingQueueId.value = null;
  }
};

const isUpdatingInboxId = ref(null);
const toggleInboxAutoAssignment = async (inbox, enabled) => {
  isUpdatingInboxId.value = inbox.id;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: inbox.id,
      formData: false,
      enable_auto_assignment: enabled,
    });
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.DISTRIBUTION.WHATSAPP_INBOXES.API.ERROR'));
  } finally {
    isUpdatingInboxId.value = null;
  }
};

// --- Portal do Cliente ---
const portalEnabled = ref(false);
const portalMaxOpenChats = ref(null);
const portalExcludedAgentIds = ref([]);
const isSavingPortal = ref(false);

// --- Excecao da distribuicao de WhatsApp ---
const whatsappMaxOpenChats = ref(null);
const whatsappExcludedAgentIds = ref([]);
const isSavingWhatsapp = ref(false);

const syncFromAccountSettings = () => {
  const settings = currentAccount.value?.settings || {};
  portalEnabled.value = settings.client_portal_auto_assignment_enabled ?? false;
  portalMaxOpenChats.value =
    settings.client_portal_auto_assignment_max_open_chats ?? null;
  portalExcludedAgentIds.value =
    settings.client_portal_auto_assignment_excluded_agent_ids || [];
  whatsappMaxOpenChats.value =
    settings.whatsapp_auto_assignment_max_open_chats ?? null;
  whatsappExcludedAgentIds.value =
    settings.whatsapp_auto_assignment_excluded_agent_ids || [];
};

watch(currentAccount, syncFromAccountSettings, { deep: true, immediate: true });

const togglePortalExcludedAgent = agentId => {
  portalExcludedAgentIds.value = portalExcludedAgentIds.value.includes(agentId)
    ? portalExcludedAgentIds.value.filter(id => id !== agentId)
    : [...portalExcludedAgentIds.value, agentId];
};

const toggleWhatsappExcludedAgent = agentId => {
  whatsappExcludedAgentIds.value = whatsappExcludedAgentIds.value.includes(
    agentId
  )
    ? whatsappExcludedAgentIds.value.filter(id => id !== agentId)
    : [...whatsappExcludedAgentIds.value, agentId];
};

// Liga/desliga em si salva na hora (autosave, como as Filas e as caixas de
// WhatsApp acima); so' o limite e a lista de excecao precisam do botao
// Salvar, por serem varios campos de uma vez.
const togglePortalEnabled = async enabled => {
  portalEnabled.value = enabled;
  try {
    await updateAccount(
      { client_portal_auto_assignment_enabled: enabled },
      { silent: true }
    );
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.DISTRIBUTION.PORTAL.API.ERROR'));
  }
};

const savePortalSettings = async () => {
  isSavingPortal.value = true;
  try {
    await updateAccount(
      {
        client_portal_auto_assignment_max_open_chats:
          portalMaxOpenChats.value || null,
        client_portal_auto_assignment_excluded_agent_ids:
          portalExcludedAgentIds.value,
      },
      { silent: true }
    );
    useAlert(t('TICKET.SETTINGS.DISTRIBUTION.PORTAL.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.DISTRIBUTION.PORTAL.API.ERROR'));
  } finally {
    isSavingPortal.value = false;
  }
};

const saveWhatsappExceptions = async () => {
  isSavingWhatsapp.value = true;
  try {
    await updateAccount(
      {
        whatsapp_auto_assignment_max_open_chats:
          whatsappMaxOpenChats.value || null,
        whatsapp_auto_assignment_excluded_agent_ids:
          whatsappExcludedAgentIds.value,
      },
      { silent: true }
    );
    useAlert(t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.API.ERROR'));
  } finally {
    isSavingWhatsapp.value = false;
  }
};

onBeforeMount(() => {
  store.dispatch('queues/get');
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('inboxes/get');
});
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.DISTRIBUTION.TITLE')"
        :description="t('TICKET.SETTINGS.DISTRIBUTION.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="flex flex-col w-full max-w-2xl gap-5">
        <!-- Nota explicativa: a maioria das conversas de WhatsApp chega numa
             Fila via o fluxo de triagem - o liga/desliga por caixa abaixo so'
             importa pra quem nao passa por fila nenhuma. -->
        <div
          class="flex items-start gap-3 px-4 py-3 border rounded-xl border-n-amber-4 bg-n-amber-2"
        >
          <span class="i-lucide-info text-n-amber-11 size-4 mt-0.5 shrink-0" />
          <p class="mb-0 text-body-para text-n-amber-11">
            {{ t('TICKET.SETTINGS.DISTRIBUTION.FLOW_NOTE') }}
          </p>
        </div>

        <!-- Filas: o liga/desliga de verdade pra conversa que chega numa Fila
             (ex: triagem por IA roteando pra uma Mesa/Fila). -->
        <div
          class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="px-5 py-4 border-b border-n-weak">
            <h3 class="text-heading-2 text-n-slate-12">
              {{ t('TICKET.SETTINGS.DISTRIBUTION.QUEUES.TITLE') }}
            </h3>
            <p class="mb-0 text-body-para text-n-slate-11">
              {{ t('TICKET.SETTINGS.DISTRIBUTION.QUEUES.DESCRIPTION') }}
            </p>
          </div>
          <ul v-if="queues.length" class="m-0 divide-y divide-n-weak list-none">
            <li
              v-for="queue in queues"
              :key="queue.id"
              class="flex items-center justify-between gap-4 px-5 py-3"
            >
              <div class="min-w-0">
                <p class="mb-0 text-sm font-medium truncate text-n-slate-12">
                  {{ queue.name }}
                </p>
                <p class="mb-0 text-xs truncate text-n-slate-11">
                  {{ teamNameById(queue.team_id) }}
                </p>
              </div>
              <select
                class="mb-0 w-48 shrink-0"
                :value="queue.distribution_strategy"
                :disabled="isUpdatingQueueId === queue.id"
                @change="updateQueueStrategy(queue, $event.target.value)"
              >
                <option
                  v-for="strategy in DISTRIBUTION_STRATEGIES"
                  :key="strategy"
                  :value="strategy"
                >
                  {{
                    t(
                      `QUEUES_SETTINGS.FORM.DISTRIBUTION.OPTIONS.${strategy.toUpperCase()}`
                    )
                  }}
                </option>
              </select>
            </li>
          </ul>
          <p v-else class="px-5 py-4 mb-0 text-sm text-n-slate-11">
            {{ t('TICKET.SETTINGS.DISTRIBUTION.QUEUES.EMPTY') }}
          </p>
        </div>

        <!-- Caixas de WhatsApp: o liga/desliga nativo por caixa (so' tem
             efeito pra conversa que NAO passa por nenhuma Fila). -->
        <div
          class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="px-5 py-4 border-b border-n-weak">
            <h3 class="text-heading-2 text-n-slate-12">
              {{ t('TICKET.SETTINGS.DISTRIBUTION.WHATSAPP_INBOXES.TITLE') }}
            </h3>
            <p class="mb-0 text-body-para text-n-slate-11">
              {{
                t('TICKET.SETTINGS.DISTRIBUTION.WHATSAPP_INBOXES.DESCRIPTION')
              }}
            </p>
          </div>
          <ul
            v-if="whatsappInboxes.length"
            class="m-0 divide-y divide-n-weak list-none"
          >
            <li
              v-for="inbox in whatsappInboxes"
              :key="inbox.id"
              class="flex items-center justify-between gap-4 px-5 py-3"
            >
              <p class="mb-0 text-sm font-medium truncate text-n-slate-12">
                {{ inbox.name }}
              </p>
              <Switch
                :model-value="inbox.enable_auto_assignment"
                :disabled="isUpdatingInboxId === inbox.id"
                @update:model-value="
                  value => toggleInboxAutoAssignment(inbox, value)
                "
              />
            </li>
          </ul>
          <p v-else class="px-5 py-4 mb-0 text-sm text-n-slate-11">
            {{ t('TICKET.SETTINGS.DISTRIBUTION.WHATSAPP_INBOXES.EMPTY') }}
          </p>
        </div>

        <!-- Exceçao da distribuicao de WhatsApp: vale pro rodizio das caixas
             acima E pro rodizio das Filas quando a caixa e' WhatsApp. -->
        <div
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="flex flex-col gap-1">
            <h3 class="text-heading-2 text-n-slate-12">
              {{ t('TICKET.SETTINGS.DISTRIBUTION.WHATSAPP_EXCEPTIONS_TITLE') }}
            </h3>
            <p class="mb-0 text-body-para text-n-slate-11">
              {{ t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.DESCRIPTION') }}
            </p>
          </div>
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
              v-model.number="whatsappMaxOpenChats"
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
                  :checked="whatsappExcludedAgentIds.includes(agent.id)"
                  @change="toggleWhatsappExcludedAgent(agent.id)"
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
          <div class="flex justify-end">
            <NextButton
              type="button"
              size="sm"
              :is-loading="isSavingWhatsapp"
              :label="t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.SAVE')"
              @click="saveWhatsappExceptions"
            />
          </div>
        </div>

        <!-- Portal do Cliente: liga/desliga + limite + excecao, tudo junto -
             e' uma unica conta (nao tem uma caixa por conta igual WhatsApp). -->
        <div
          class="flex flex-col w-full gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
        >
          <div class="flex items-center justify-between gap-4">
            <div class="flex flex-col gap-1">
              <h3 class="text-heading-2 text-n-slate-12">
                {{
                  t('TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.TITLE')
                }}
              </h3>
              <p class="mb-0 text-body-para text-n-slate-11">
                {{
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <Switch
              :model-value="portalEnabled"
              @update:model-value="togglePortalEnabled"
            />
          </div>

          <template v-if="portalEnabled">
            <WithLabel
              :label="
                t(
                  'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.MAX_OPEN_CHATS.LABEL'
                )
              "
              :help-message="
                t(
                  'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.MAX_OPEN_CHATS.HELP'
                )
              "
            >
              <input
                v-model.number="portalMaxOpenChats"
                type="number"
                min="1"
                class="mb-0 max-w-xs"
                :placeholder="
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.MAX_OPEN_CHATS.PLACEHOLDER'
                  )
                "
              />
            </WithLabel>

            <WithLabel
              :label="
                t(
                  'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.EXCLUDED_AGENTS.LABEL'
                )
              "
              :help-message="
                t(
                  'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.EXCLUDED_AGENTS.HELP'
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
                    :checked="portalExcludedAgentIds.includes(agent.id)"
                    @change="togglePortalExcludedAgent(agent.id)"
                  />
                  {{ agent.name }}
                </label>
              </div>
              <p v-else class="mb-0 text-xs text-n-slate-11">
                {{
                  t(
                    'TICKET.SETTINGS.AUTOMATION.PORTAL_AUTO_ASSIGNMENT.EXCLUDED_AGENTS.EMPTY'
                  )
                }}
              </p>
            </WithLabel>

            <div class="flex justify-end">
              <NextButton
                type="button"
                size="sm"
                :is-loading="isSavingPortal"
                :label="t('TICKET.SETTINGS.DISTRIBUTION.PORTAL.SAVE')"
                @click="savePortalSettings"
              />
            </div>
          </template>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
