<script setup>
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../SettingsSubPageHeader.vue';
import FlowSteps from './FlowSteps.vue';

const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const flowId = computed(() => Number(route.params.conversationFlowId));
const flow = computed(() => getters['conversationFlows/getConversationFlow'].value(flowId.value));
const steps = computed(() => getters['flowSteps/getSteps'].value(flowId.value));
const uiFlags = computed(() => getters['conversationFlows/getUIFlags'].value);

const name = ref('');
const description = ref('');
const active = ref(true);

watch(
  flow,
  newFlow => {
    if (!newFlow) return;
    name.value = newFlow.name;
    description.value = newFlow.description;
    active.value = newFlow.active;
  },
  { immediate: true }
);

const fetchFlow = async () => {
  await store.dispatch('conversationFlows/show', flowId.value);
  await store.dispatch('flowSteps/fetch', flowId.value);
};

onBeforeMount(fetchFlow);

const saveDetails = async () => {
  try {
    await store.dispatch('conversationFlows/update', {
      id: flowId.value,
      name: name.value,
      description: description.value,
      active: active.value,
    });
    useAlert(t('CONVERSATION_FLOWS_SETTINGS.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.EDIT.API.ERROR_MESSAGE'));
  }
};

const goBack = () => {
  router.push({ name: 'conversation_flows_list' });
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6 overflow-y-auto">
    <PageHeader
      :header-title="$t('CONVERSATION_FLOWS_SETTINGS.EDITOR.TITLE')"
      :header-content="$t('CONVERSATION_FLOWS_SETTINGS.EDITOR.DESC')"
    />
    <div v-if="flow" class="flex flex-col gap-6 max-w-4xl">
      <form class="flex flex-wrap mx-0 gap-4" @submit.prevent="saveDetails">
        <woot-input
          v-model="name"
          class="w-full"
          :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.NAME.LABEL')"
        />
        <woot-input
          v-model="description"
          class="w-full"
          :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.DESCRIPTION.LABEL')"
        />
        <div class="flex items-center w-full gap-2">
          <input v-model="active" type="checkbox" :value="true" />
          <label>{{ $t('CONVERSATION_FLOWS_SETTINGS.FORM.ACTIVE.LABEL') }}</label>
        </div>
        <div class="flex items-center justify-between w-full gap-2 py-2">
          <Button
            faded
            slate
            type="button"
            :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.BACK')"
            @click="goBack"
          />
          <Button
            type="submit"
            :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.SAVE_DETAILS')"
            :is-loading="uiFlags.isUpdating"
          />
        </div>
      </form>

      <FlowSteps :flow-id="flowId" :steps="steps" />
    </div>
  </div>
</template>
