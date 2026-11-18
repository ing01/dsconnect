<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();

const deletingForm = ref(null);
const showDeletePopup = ref(false);

const forms = computed(() => getters['forms/getForms'].value);
const uiFlags = computed(() => getters['forms/getUIFlags'].value);

const tableHeaders = computed(() => [
  t('FORMS.LIST.TABLE.NAME'),
  t('FORMS.LIST.TABLE.STATUS'),
  t('FORMS.LIST.TABLE.FIELDS'),
  t('FORMS.LIST.TABLE.ACTIONS'),
]);

const fieldCount = form => form.fields?.length ?? 0;
const statusColor = form => (form.status === 'published' ? 'teal' : 'slate');

const openForm = form => {
  router.push({ name: 'forms_edit', params: { formId: form.id } });
};
const openNewForm = () => {
  router.push({ name: 'forms_new' });
};

const openDeletePopup = form => {
  deletingForm.value = form;
  showDeletePopup.value = true;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const confirmDeletion = async () => {
  const form = deletingForm.value;
  closeDeletePopup();
  try {
    await store.dispatch('forms/delete', form.id);
    useAlert(t('FORMS.LIST.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('FORMS.LIST.DELETE.ERROR'));
  }
};

onMounted(() => {
  store.dispatch('forms/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching && !forms.length"
    :loading-message="t('FORMS.LIST.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('FORMS.LIST.HEADER')"
        :description="t('FORMS.LIST.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('FORMS.LIST.ADD_BUTTON')"
            size="sm"
            @click="openNewForm"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="forms"
        :no-data-message="t('FORMS.LIST.EMPTY')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="form in items" :key="form.id" :item="form">
            <template #default>
              <BaseTableCell>
                <button
                  type="button"
                  class="text-body-main text-n-slate-12 hover:text-n-brand text-left"
                  @click="openForm(form)"
                >
                  {{ form.name }}
                </button>
              </BaseTableCell>

              <BaseTableCell>
                <WootLabel
                  :label="
                    form.status === 'published'
                      ? t('FORMS.STATUS.PUBLISHED')
                      : t('FORMS.STATUS.DRAFT')
                  "
                  :color="statusColor(form)"
                  compact
                />
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ fieldCount(form) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="t('FORMS.LIST.EDIT_TOOLTIP')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openForm(form)"
                  />
                  <Button
                    v-tooltip.top="t('FORMS.LIST.DELETE_TOOLTIP')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(form)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('FORMS.LIST.DELETE.TITLE')"
      :message="t('FORMS.LIST.DELETE.MESSAGE')"
      :message-value="` ${deletingForm?.name}?`"
      :confirm-text="t('FORMS.LIST.DELETE.CONFIRM')"
      :reject-text="t('FORMS.LIST.DELETE.CANCEL')"
    />
  </SettingsLayout>
</template>
