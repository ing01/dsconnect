<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import ChecklistFormDialog from './ChecklistFormDialog.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const showAddPopup = ref(false);
const editingChecklist = ref(null);
const deletingChecklist = ref(null);
const showDeletePopup = ref(false);

const checklists = computed(() => getters['checklists/getChecklists'].value);
const uiFlags = computed(() => getters['checklists/getUIFlags'].value);

const tableHeaders = computed(() => [
  t('CHECKLISTS.LIST.TABLE.NAME'),
  t('CHECKLISTS.LIST.TABLE.ITEMS'),
  t('CHECKLISTS.LIST.TABLE.ACTIONS'),
]);

const itemCount = checklist => checklist.items?.length ?? 0;

const openAddPopup = () => {
  editingChecklist.value = null;
  showAddPopup.value = true;
};
const openEditPopup = checklist => {
  editingChecklist.value = checklist;
  showAddPopup.value = true;
};
const hidePopup = () => {
  showAddPopup.value = false;
  editingChecklist.value = null;
};

const openDeletePopup = checklist => {
  deletingChecklist.value = checklist;
  showDeletePopup.value = true;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const confirmDeletion = async () => {
  const checklist = deletingChecklist.value;
  closeDeletePopup();
  try {
    await store.dispatch('checklists/delete', checklist.id);
    useAlert(t('CHECKLISTS.LIST.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('CHECKLISTS.LIST.DELETE.ERROR'));
  }
};

onMounted(() => {
  store.dispatch('checklists/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching && !checklists.length"
    :loading-message="t('PROJECTS.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CHECKLISTS.LIST.HEADER')"
        :description="t('CHECKLISTS.LIST.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('CHECKLISTS.LIST.ADD_BUTTON')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="checklists"
        :no-data-message="t('CHECKLISTS.LIST.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="checklist in items"
            :key="checklist.id"
            :item="checklist"
          >
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ checklist.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ itemCount(checklist) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="t('CHECKLISTS.LIST.EDIT_TOOLTIP')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(checklist)"
                  />
                  <Button
                    v-tooltip.top="t('CHECKLISTS.LIST.DELETE_TOOLTIP')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(checklist)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hidePopup">
      <ChecklistFormDialog
        :checklist="editingChecklist"
        @close="hidePopup"
        @saved="hidePopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('CHECKLISTS.LIST.DELETE.TITLE')"
      :message="t('CHECKLISTS.LIST.DELETE.MESSAGE')"
      :message-value="` ${deletingChecklist?.name}?`"
      :confirm-text="t('CHECKLISTS.LIST.DELETE.CONFIRM')"
      :reject-text="t('CHECKLISTS.LIST.DELETE.CANCEL')"
    />
  </SettingsLayout>
</template>
