<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const router = useRouter();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedFlow = ref({});
const newFlowName = ref('');
const newFlowDescription = ref('');

const records = computed(() => getters['conversationFlows/getConversationFlows'].value);
const uiFlags = computed(() => getters['conversationFlows/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedFlow.value.name}?`);

const openAddPopup = () => {
  newFlowName.value = '';
  newFlowDescription.value = '';
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const createFlow = async () => {
  if (!newFlowName.value.trim()) return;
  try {
    const flow = await store.dispatch('conversationFlows/create', {
      name: newFlowName.value,
      description: newFlowDescription.value,
      active: true,
    });
    useAlert(t('CONVERSATION_FLOWS_SETTINGS.ADD.API.SUCCESS_MESSAGE'));
    hideAddPopup();
    router.push({ name: 'conversation_flows_edit', params: { conversationFlowId: flow.id } });
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.ADD.API.ERROR_MESSAGE'));
  }
};

const openDeletePopup = flow => {
  showDeleteConfirmationPopup.value = true;
  selectedFlow.value = flow;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteFlow = async id => {
  try {
    await store.dispatch('conversationFlows/delete', id);
    useAlert(t('CONVERSATION_FLOWS_SETTINGS.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION_FLOWS_SETTINGS.DELETE.API.ERROR_MESSAGE'));
  } finally {
    loading.value[selectedFlow.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedFlow.value.id] = true;
  closeDeletePopup();
  deleteFlow(selectedFlow.value.id);
};

const editFlow = flow => {
  router.push({ name: 'conversation_flows_edit', params: { conversationFlowId: flow.id } });
};

const tableHeaders = computed(() => {
  return [
    t('CONVERSATION_FLOWS_SETTINGS.LIST.TABLE_HEADER.NAME'),
    t('CONVERSATION_FLOWS_SETTINGS.LIST.TABLE_HEADER.STEPS'),
    t('CONVERSATION_FLOWS_SETTINGS.LIST.TABLE_HEADER.ACTIVE'),
    t('CONVERSATION_FLOWS_SETTINGS.LIST.TABLE_HEADER.ACTION'),
  ];
});

onBeforeMount(() => {
  store.dispatch('conversationFlows/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('CONVERSATION_FLOWS_SETTINGS.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('CONVERSATION_FLOWS_SETTINGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CONVERSATION_FLOWS_SETTINGS.HEADER')"
        :description="$t('CONVERSATION_FLOWS_SETTINGS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="$t('CONVERSATION_FLOWS_SETTINGS.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="records"
        :no-data-message="$t('CONVERSATION_FLOWS_SETTINGS.LIST.404')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="flow in items" :key="flow.id" :item="flow">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ flow.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ flow.flow_steps?.length || 0 }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{
                    flow.active
                      ? $t('CONVERSATION_FLOWS_SETTINGS.LIST.ACTIVE')
                      : $t('CONVERSATION_FLOWS_SETTINGS.LIST.INACTIVE')
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('CONVERSATION_FLOWS_SETTINGS.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[flow.id]"
                    @click="editFlow(flow)"
                  />
                  <Button
                    v-tooltip.top="$t('CONVERSATION_FLOWS_SETTINGS.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[flow.id]"
                    @click="openDeletePopup(flow)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CONVERSATION_FLOWS_SETTINGS.ADD.TITLE')"
          :header-content="$t('CONVERSATION_FLOWS_SETTINGS.ADD.DESC')"
        />
        <form class="flex flex-wrap mx-0" @submit.prevent="createFlow">
          <woot-input
            v-model="newFlowName"
            class="w-full"
            :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.NAME.LABEL')"
            :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.FORM.NAME.PLACEHOLDER')"
          />
          <woot-input
            v-model="newFlowDescription"
            class="w-full"
            :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('CONVERSATION_FLOWS_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
          />
          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <Button
              faded
              slate
              type="reset"
              :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.CANCEL')"
              @click.prevent="hideAddPopup"
            />
            <Button
              type="submit"
              :label="$t('CONVERSATION_FLOWS_SETTINGS.FORM.CREATE')"
              :disabled="!newFlowName.trim() || uiFlags.isCreating"
              :is-loading="uiFlags.isCreating"
            />
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION_FLOWS_SETTINGS.DELETE.CONFIRM.TITLE')"
      :message="$t('CONVERSATION_FLOWS_SETTINGS.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('CONVERSATION_FLOWS_SETTINGS.DELETE.CONFIRM.YES')"
      :reject-text="$t('CONVERSATION_FLOWS_SETTINGS.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
