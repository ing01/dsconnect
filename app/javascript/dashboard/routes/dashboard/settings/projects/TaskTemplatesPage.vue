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
import AddProjectTaskTemplate from './AddProjectTaskTemplate.vue';
import EditProjectTaskTemplate from './EditProjectTaskTemplate.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const editingTemplate = ref(null);
const deletingTemplate = ref(null);
const showDeletePopup = ref(false);

const templates = computed(
  () => getters['projectTaskTemplates/getTaskTemplates'].value
);
const uiFlags = computed(() => getters['projectTaskTemplates/getUIFlags'].value);

const tableHeaders = computed(() => [
  t('PROJECT_TASKS.LIST.TABLE.NAME'),
  t('PROJECT_TASKS.LIST.TABLE.DEFAULT_TITLE'),
  t('PROJECT_TASKS.LIST.TABLE.DUE_DAYS'),
  t('PROJECT_TASKS.LIST.TABLE.NEXT_STAGE'),
  t('PROJECT_TASKS.LIST.TABLE.ACTIONS'),
]);

const stageLabel = template =>
  template.next_project_stage
    ? t(
        `PROJECTS.STAGES.${template.next_project_stage.toUpperCase()}`,
        template.next_project_stage
      )
    : '—';

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};
const openEditPopup = template => {
  editingTemplate.value = template;
  showEditPopup.value = true;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
  editingTemplate.value = null;
};

const openDeletePopup = template => {
  deletingTemplate.value = template;
  showDeletePopup.value = true;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const confirmDeletion = async () => {
  const template = deletingTemplate.value;
  closeDeletePopup();
  try {
    await store.dispatch('projectTaskTemplates/delete', template.id);
    useAlert(t('PROJECT_TASKS.LIST.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('PROJECT_TASKS.LIST.DELETE.ERROR')
    );
  }
};

onMounted(() => {
  store.dispatch('projectTaskTemplates/get');
  store.dispatch('agents/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching && !templates.length"
    :loading-message="t('PROJECTS.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PROJECT_TASKS.LIST.HEADER')"
        :description="t('PROJECT_TASKS.LIST.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('PROJECT_TASKS.LIST.ADD_BUTTON')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="templates"
        :no-data-message="t('PROJECT_TASKS.LIST.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="template in items"
            :key="template.id"
            :item="template"
          >
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ template.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ template.default_ticket_title }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ template.due_days }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ stageLabel(template) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="t('PROJECT_TASKS.LIST.EDIT_TOOLTIP')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(template)"
                  />
                  <Button
                    v-tooltip.top="t('PROJECT_TASKS.LIST.DELETE_TOOLTIP')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(template)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddProjectTaskTemplate @close="hideAddPopup" @saved="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditProjectTaskTemplate
        v-if="editingTemplate"
        :task-template="editingTemplate"
        @close="hideEditPopup"
        @saved="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('PROJECT_TASKS.LIST.DELETE.TITLE')"
      :message="t('PROJECT_TASKS.LIST.DELETE.MESSAGE')"
      :message-value="` ${deletingTemplate?.name}?`"
      :confirm-text="t('PROJECT_TASKS.LIST.DELETE.CONFIRM')"
      :reject-text="t('PROJECT_TASKS.LIST.DELETE.CANCEL')"
    />
  </SettingsLayout>
</template>
