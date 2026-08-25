<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const props = defineProps({
  teamId: { type: [Number, String], default: null },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const formDialog = ref(null);
const deleteDialog = ref(null);
const editing = ref(null);
const name = ref('');
const isSaving = ref(false);

// Categories are scoped to the Mesa, exactly like the Estagios above.
const categories = computed(
  () => getters['ticketColumns/getCategories'].value(props.teamId) || []
);

const headers = computed(() => [
  t('TICKET.SETTINGS.CATEGORIES.NAME'),
  t('TICKET.SETTINGS.TABLE.ACTIONS'),
]);

const openForm = category => {
  editing.value = category || null;
  name.value = category?.name || '';
  formDialog.value?.open();
};

const save = async () => {
  const trimmed = name.value.trim();
  if (!trimmed || isSaving.value) return;

  isSaving.value = true;
  try {
    const action = editing.value
      ? store.dispatch('ticketColumns/updateCategory', {
          teamId: props.teamId,
          categoryId: editing.value.id,
          name: trimmed,
        })
      : store.dispatch('ticketColumns/createCategory', {
          teamId: props.teamId,
          name: trimmed,
        });
    await action;
    formDialog.value?.close();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};

const confirmDelete = category => {
  editing.value = category;
  deleteDialog.value?.open();
};

const remove = async () => {
  try {
    await store.dispatch('ticketColumns/deleteCategory', {
      teamId: props.teamId,
      categoryId: editing.value.id,
    });
    deleteDialog.value?.close();
  } catch (error) {
    // The backend refuses to delete a category that still has tickets; surface
    // that rather than a generic failure.
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  }
};

watch(
  () => props.teamId,
  teamId => {
    if (teamId) store.dispatch('ticketColumns/fetchCategories', teamId);
  },
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col gap-3 mt-8 min-w-0">
    <div class="flex items-center justify-between gap-2 min-w-0">
      <div class="flex flex-col min-w-0">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CATEGORIES.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET.SETTINGS.CATEGORIES.DESCRIPTION') }}
        </p>
      </div>
      <Button
        size="sm"
        class="flex-shrink-0"
        :disabled="!teamId"
        :label="t('TICKET.SETTINGS.CATEGORIES.ADD')"
        @click="openForm(null)"
      />
    </div>

    <BaseTable
      :headers="headers"
      :items="categories"
      :no-data-message="t('TICKET.SETTINGS.CATEGORIES.EMPTY')"
    >
      <template #row="{ items }">
        <BaseTableRow
          v-for="category in items"
          :key="category.id"
          :item="category"
        >
          <template #default>
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">
                {{ category.name }}
              </span>
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex justify-end flex-shrink-0 gap-3">
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-pencil"
                  :aria-label="t('TICKET.SETTINGS.CATEGORIES.EDIT')"
                  @click="openForm(category)"
                />
                <Button
                  variant="ghost"
                  color="ruby"
                  size="xs"
                  icon="i-lucide-trash-2"
                  :aria-label="t('TICKET.SETTINGS.CATEGORIES.DELETE')"
                  @click="confirmDelete(category)"
                />
              </div>
            </BaseTableCell>
          </template>
        </BaseTableRow>
      </template>
    </BaseTable>

    <Dialog
      ref="formDialog"
      width="md"
      :title="
        editing
          ? t('TICKET.SETTINGS.CATEGORIES.EDIT')
          : t('TICKET.SETTINGS.CATEGORIES.ADD')
      "
      :confirm-button-label="t('TICKET.SETTINGS.CATEGORIES.SAVE')"
      :disable-confirm-button="!name.trim()"
      :is-loading="isSaving"
      @confirm="save"
    >
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CATEGORIES.NAME') }}
        </span>
        <input
          v-model="name"
          type="text"
          class="w-full mb-0"
          @keyup.enter="save"
        />
      </label>
    </Dialog>

    <Dialog
      ref="deleteDialog"
      type="alert"
      width="md"
      :title="t('TICKET.SETTINGS.CATEGORIES.DELETE')"
      :description="editing?.name"
      :confirm-button-label="t('TICKET.SETTINGS.CATEGORIES.DELETE')"
      @confirm="remove"
    />
  </section>
</template>
