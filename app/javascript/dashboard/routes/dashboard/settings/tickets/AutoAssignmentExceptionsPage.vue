<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { currentAccount, updateAccount } = useAccount();

// Duas listas independentes (pedido da Ingrid, 2026-11-09): um agente pode
// estar fora da distribuição do WhatsApp e continuar no rodízio do Portal,
// ou o contrário - cada canal lê a sua própria chave
// (Account#whatsapp_auto_assignment_excluded_agent_ids /
// Account#client_portal_auto_assignment_excluded_agent_ids).
const whatsappExcludedAgentIds = ref([]);
const portalExcludedAgentIds = ref([]);
const isSubmitting = ref(false);

const agents = computed(() => getters['agents/getAgents'].value);

onBeforeMount(() => {
  store.dispatch('agents/get');
});

watch(
  currentAccount,
  () => {
    const settings = currentAccount.value?.settings || {};
    whatsappExcludedAgentIds.value =
      settings.whatsapp_auto_assignment_excluded_agent_ids || [];
    portalExcludedAgentIds.value =
      settings.client_portal_auto_assignment_excluded_agent_ids || [];
  },
  { deep: true, immediate: true }
);

const toggleWhatsappExcludedAgent = agentId => {
  whatsappExcludedAgentIds.value = whatsappExcludedAgentIds.value.includes(
    agentId
  )
    ? whatsappExcludedAgentIds.value.filter(id => id !== agentId)
    : [...whatsappExcludedAgentIds.value, agentId];
};

const togglePortalExcludedAgent = agentId => {
  portalExcludedAgentIds.value = portalExcludedAgentIds.value.includes(agentId)
    ? portalExcludedAgentIds.value.filter(id => id !== agentId)
    : [...portalExcludedAgentIds.value, agentId];
};

const handleSubmit = async () => {
  isSubmitting.value = true;
  try {
    await updateAccount(
      {
        whatsapp_auto_assignment_excluded_agent_ids:
          whatsappExcludedAgentIds.value,
        client_portal_auto_assignment_excluded_agent_ids:
          portalExcludedAgentIds.value,
      },
      { silent: true }
    );
    useAlert(t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.TITLE')"
        :description="
          t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.DESCRIPTION')
        "
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
          <div class="flex flex-col gap-3 px-5 py-4">
            <h3 class="text-heading-2 text-n-slate-12">
              {{
                t(
                  'TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.WHATSAPP_SECTION_TITLE'
                )
              }}
            </h3>
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
          </div>

          <div class="flex flex-col gap-3 px-5 py-4">
            <h3 class="text-heading-2 text-n-slate-12">
              {{
                t(
                  'TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.PORTAL_SECTION_TITLE'
                )
              }}
            </h3>
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
          </div>
        </div>

        <div class="flex justify-end">
          <NextButton
            type="submit"
            :is-loading="isSubmitting"
            :label="t('TICKET.SETTINGS.AUTO_ASSIGNMENT_EXCEPTIONS.SAVE')"
          />
        </div>
      </form>
    </template>
  </SettingsLayout>
</template>
