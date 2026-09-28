<script setup>
// Secao generica pra listas simples do quadro de Sugestoes (Prioridades,
// Categorias) - so nome, sem reordenar nem travar exclusao (excluir uma em
// uso apenas desmarca a sugestao, ver SuggestionPriority/SuggestionCategory).
// Usada duas vezes na mesma tela; um terceiro caso repetiria a mesma forma
// o bastante pra virar mais props aqui, nao um componente por lista.
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const props = defineProps({
  storeModule: { type: String, required: true },
  i18nPrefix: { type: String, required: true },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const tt = key => t(`${props.i18nPrefix}.${key}`);

const items = computed(() => getters[`${props.storeModule}/getItems`].value);
const uiFlags = computed(
  () => getters[`${props.storeModule}/getUIFlags`].value
);

const showAddPopup = ref(false);
const editing = ref(null);
const name = ref('');
const isSubmitting = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selected = ref(null);

const isInvalid = computed(() => !name.value.trim());
const deleteMessage = computed(() => ` ${selected.value?.name}?`);

const openAddPopup = () => {
  editing.value = null;
  name.value = '';
  showAddPopup.value = true;
};
const openEditPopup = item => {
  editing.value = item;
  name.value = item.name;
  showAddPopup.value = true;
};
const closeFormPopup = () => {
  showAddPopup.value = false;
};

const submitForm = async () => {
  if (isInvalid.value) return;
  isSubmitting.value = true;
  try {
    if (editing.value) {
      await store.dispatch(`${props.storeModule}/update`, {
        id: editing.value.id,
        name: name.value.trim(),
      });
      useAlert(tt('API.UPDATE_SUCCESS'));
    } else {
      await store.dispatch(`${props.storeModule}/create`, {
        name: name.value.trim(),
      });
      useAlert(tt('API.CREATE_SUCCESS'));
    }
    closeFormPopup();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || tt('API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const openDeletePopup = item => {
  selected.value = item;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = async () => {
  const item = selected.value;
  closeDeletePopup();
  try {
    await store.dispatch(`${props.storeModule}/delete`, item.id);
    useAlert(tt('API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || tt('API.ERROR'));
  }
};

onBeforeMount(() => store.dispatch(`${props.storeModule}/get`));
</script>

<template>
  <section class="flex flex-col gap-3 pt-4 border-t border-n-weak">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ tt('HEADER') }}
        </h3>
        <p class="mt-0.5 mb-0 text-xs text-n-slate-11">{{ tt('DESCRIPTION') }}</p>
      </div>
      <Button :label="tt('ADD')" size="sm" @click="openAddPopup" />
    </div>

    <p v-if="!items.length && !uiFlags.isFetching" class="mb-0 text-sm text-n-slate-10">
      {{ tt('EMPTY') }}
    </p>

    <BaseTable v-else :headers="[tt('TABLE.NAME'), tt('TABLE.ACTIONS')]" :items="items">
      <template #row="{ items: rows }">
        <BaseTableRow v-for="item in rows" :key="item.id" :item="item">
          <template #default>
            <BaseTableCell>
              <span class="text-body-main text-n-slate-12">{{ item.name }}</span>
            </BaseTableCell>
            <BaseTableCell align="end">
              <div class="flex justify-end flex-shrink-0 gap-3">
                <Button
                  v-tooltip.top="tt('EDIT')"
                  icon="i-woot-edit-pen"
                  slate
                  sm
                  @click="openEditPopup(item)"
                />
                <Button
                  v-tooltip.top="tt('DELETE')"
                  icon="i-woot-bin"
                  slate
                  sm
                  class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                  @click="openDeletePopup(item)"
                />
              </div>
            </BaseTableCell>
          </template>
        </BaseTableRow>
      </template>
    </BaseTable>

    <woot-modal v-model:show="showAddPopup" :on-close="closeFormPopup">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="editing ? tt('EDIT_TITLE') : tt('ADD_TITLE')"
        />
        <form class="flex flex-col w-full gap-4 p-8" @submit.prevent="submitForm">
          <NextInput
            v-model="name"
            :label="tt('FORM.NAME.LABEL')"
            :placeholder="tt('FORM.NAME.PLACEHOLDER')"
          />
          <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
            <Button
              faded
              slate
              type="button"
              :label="tt('CANCEL')"
              @click="closeFormPopup"
            />
            <Button
              type="submit"
              :label="editing ? tt('UPDATE') : tt('SUBMIT')"
              :disabled="isInvalid"
              :is-loading="isSubmitting"
            />
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="tt('DELETE_CONFIRM.TITLE')"
      :message="tt('DELETE_CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="tt('DELETE_CONFIRM.CONFIRM')"
      :reject-text="tt('DELETE_CONFIRM.CANCEL')"
    />
  </section>
</template>
