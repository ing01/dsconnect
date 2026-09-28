<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import AddSuggestionColumn from './AddSuggestionColumn.vue';
import EditSuggestionColumn from './EditSuggestionColumn.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const selectedColumn = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const isReordering = ref(false);

const uiFlags = computed(() => getters['suggestionColumns/getUIFlags'].value);
const columns = computed(() => getters['suggestionColumns/getColumns'].value);

const tableHeaders = computed(() => [
  t('SUGGESTIONS.SETTINGS.TABLE.NAME'),
  t('SUGGESTIONS.SETTINGS.TABLE.SUGGESTIONS'),
  t('SUGGESTIONS.SETTINGS.TABLE.ACTIONS'),
]);

const deleteMessage = computed(() => ` ${selectedColumn.value.name}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};
const openEditPopup = column => {
  selectedColumn.value = column;
  showEditPopup.value = true;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};
const openDeletePopup = column => {
  selectedColumn.value = column;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  const column = selectedColumn.value;
  closeDeletePopup();
  try {
    await store.dispatch('suggestionColumns/delete', column.id);
    useAlert(t('SUGGESTIONS.SETTINGS.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('SUGGESTIONS.SETTINGS.API.DELETE_ERROR')
    );
  }
};

const moveColumn = async (index, delta) => {
  const columnIds = columns.value.map(column => column.id);
  const target = index + delta;
  if (target < 0 || target >= columnIds.length) return;

  [columnIds[index], columnIds[target]] = [columnIds[target], columnIds[index]];

  isReordering.value = true;
  try {
    await store.dispatch('suggestionColumns/reorder', columnIds);
  } catch (error) {
    useAlert(t('SUGGESTIONS.SETTINGS.API.REORDER_ERROR'));
  } finally {
    isReordering.value = false;
  }
};

onBeforeMount(() => {
  store.dispatch('suggestionColumns/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('SUGGESTIONS.SETTINGS.LOADING')"
    :no-records-found="!columns.length"
    :no-records-message="t('SUGGESTIONS.SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SUGGESTIONS.SETTINGS.HEADER')"
        :description="t('SUGGESTIONS.SETTINGS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('SUGGESTIONS.SETTINGS.ADD_COLUMN')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="columns"
        :no-data-message="t('SUGGESTIONS.SETTINGS.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="(column, index) in items"
            :key="column.id"
            :item="column"
          >
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ column.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ column.suggestions_count }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="t('SUGGESTIONS.SETTINGS.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    slate
                    sm
                    :disabled="index === 0 || isReordering"
                    @click="moveColumn(index, -1)"
                  />
                  <Button
                    v-tooltip.top="t('SUGGESTIONS.SETTINGS.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    slate
                    sm
                    :disabled="index === items.length - 1 || isReordering"
                    @click="moveColumn(index, 1)"
                  />
                  <Button
                    v-tooltip.top="t('SUGGESTIONS.SETTINGS.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(column)"
                  />
                  <Button
                    v-tooltip.top="
                      column.suggestions_count
                        ? t('SUGGESTIONS.SETTINGS.DELETE_BLOCKED_HINT')
                        : t('SUGGESTIONS.SETTINGS.DELETE')
                    "
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :disabled="column.suggestions_count > 0"
                    @click="openDeletePopup(column)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddSuggestionColumn @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditSuggestionColumn :column="selectedColumn" @close="hideEditPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('SUGGESTIONS.SETTINGS.DELETE_CONFIRM.TITLE')"
      :message="t('SUGGESTIONS.SETTINGS.DELETE_CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="t('SUGGESTIONS.SETTINGS.DELETE_CONFIRM.CONFIRM')"
      :reject-text="t('SUGGESTIONS.SETTINGS.DELETE_CONFIRM.CANCEL')"
    />
  </SettingsLayout>
</template>
