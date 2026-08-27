<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

import AddQueue from './AddQueue.vue';
import EditQueue from './EditQueue.vue';
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
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedQueue = ref({});

const records = computed(() => getters['queues/getQueues'].value);
const teams = computed(() => getters['teams/getTeams'].value);
const uiFlags = computed(() => getters['queues/getUIFlags'].value);

const teamName = teamId =>
  teams.value.find(team => team.id === teamId)?.name || '--';

const deleteMessage = computed(() => ` ${selectedQueue.value.name}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = queue => {
  showEditPopup.value = true;
  selectedQueue.value = queue;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = queue => {
  showDeleteConfirmationPopup.value = true;
  selectedQueue.value = queue;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteQueue = async id => {
  try {
    await store.dispatch('queues/delete', id);
    useAlert(t('QUEUES_SETTINGS.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('QUEUES_SETTINGS.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedQueue.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedQueue.value.id] = true;
  closeDeletePopup();
  deleteQueue(selectedQueue.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('QUEUES_SETTINGS.LIST.TABLE_HEADER.NAME'),
    t('QUEUES_SETTINGS.LIST.TABLE_HEADER.TEAM'),
    t('QUEUES_SETTINGS.LIST.TABLE_HEADER.DISTRIBUTION'),
    t('QUEUES_SETTINGS.LIST.TABLE_HEADER.ACTIVE'),
    t('QUEUES_SETTINGS.LIST.TABLE_HEADER.ACTION'),
  ];
});

onBeforeMount(() => {
  store.dispatch('queues/get');
  store.dispatch('teams/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('QUEUES_SETTINGS.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('QUEUES_SETTINGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('QUEUES_SETTINGS.HEADER')"
        :description="$t('QUEUES_SETTINGS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="$t('QUEUES_SETTINGS.HEADER_BTN_TXT')"
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
        :no-data-message="$t('QUEUES_SETTINGS.LIST.404')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="queue in items" :key="queue.id" :item="queue">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ queue.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ teamName(queue.team_id) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{
                    $t(
                      `QUEUES_SETTINGS.FORM.DISTRIBUTION.OPTIONS.${queue.distribution_strategy.toUpperCase()}`
                    )
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{
                    queue.active
                      ? $t('QUEUES_SETTINGS.LIST.ACTIVE')
                      : $t('QUEUES_SETTINGS.LIST.INACTIVE')
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('QUEUES_SETTINGS.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[queue.id]"
                    @click="openEditPopup(queue)"
                  />
                  <Button
                    v-tooltip.top="$t('QUEUES_SETTINGS.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[queue.id]"
                    @click="openDeletePopup(queue)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddQueue @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditQueue :selected-queue="selectedQueue" @close="hideEditPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('QUEUES_SETTINGS.DELETE.CONFIRM.TITLE')"
      :message="$t('QUEUES_SETTINGS.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('QUEUES_SETTINGS.DELETE.CONFIRM.YES')"
      :reject-text="$t('QUEUES_SETTINGS.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
