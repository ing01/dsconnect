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
import ModuleFormDialog from './ModuleFormDialog.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const showAddPopup = ref(false);
const editingModule = ref(null);
const deletingModule = ref(null);
const showDeletePopup = ref(false);

const modules = computed(() => getters['projectModules/getModules'].value);
const uiFlags = computed(() => getters['projectModules/getUIFlags'].value);

const tableHeaders = computed(() => [
  t('PROJECT_MODULES.LIST.TABLE.NAME'),
  t('PROJECT_MODULES.LIST.TABLE.TASKS'),
  t('PROJECT_MODULES.LIST.TABLE.ACTIONS'),
]);

const taskCount = projectModule => projectModule.task_templates?.length ?? 0;

const openAddPopup = () => {
  editingModule.value = null;
  showAddPopup.value = true;
};
const openEditPopup = projectModule => {
  editingModule.value = projectModule;
  showAddPopup.value = true;
};
const hidePopup = () => {
  showAddPopup.value = false;
  editingModule.value = null;
};

const openDeletePopup = projectModule => {
  deletingModule.value = projectModule;
  showDeletePopup.value = true;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const confirmDeletion = async () => {
  const projectModule = deletingModule.value;
  closeDeletePopup();
  try {
    await store.dispatch('projectModules/delete', projectModule.id);
    useAlert(t('PROJECT_MODULES.LIST.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('PROJECT_MODULES.LIST.DELETE.ERROR')
    );
  }
};

onMounted(() => {
  store.dispatch('projectModules/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching && !modules.length"
    :loading-message="t('PROJECTS.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PROJECT_MODULES.LIST.HEADER')"
        :description="t('PROJECT_MODULES.LIST.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('PROJECT_MODULES.LIST.ADD_BUTTON')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="modules"
        :no-data-message="t('PROJECT_MODULES.LIST.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="projectModule in items"
            :key="projectModule.id"
            :item="projectModule"
          >
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ projectModule.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ taskCount(projectModule) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="t('PROJECT_MODULES.LIST.EDIT_TOOLTIP')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(projectModule)"
                  />
                  <Button
                    v-tooltip.top="t('PROJECT_MODULES.LIST.DELETE_TOOLTIP')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(projectModule)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hidePopup">
      <ModuleFormDialog
        :project-module="editingModule"
        @close="hidePopup"
        @saved="hidePopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('PROJECT_MODULES.LIST.DELETE.TITLE')"
      :message="t('PROJECT_MODULES.LIST.DELETE.MESSAGE')"
      :message-value="` ${deletingModule?.name}?`"
      :confirm-text="t('PROJECT_MODULES.LIST.DELETE.CONFIRM')"
      :reject-text="t('PROJECT_MODULES.LIST.DELETE.CANCEL')"
    />
  </SettingsLayout>
</template>
