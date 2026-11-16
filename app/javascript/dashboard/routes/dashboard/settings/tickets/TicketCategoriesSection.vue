<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
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
// Exigir anexo na abertura. Por Categoria, porque "Erro" quase sempre precisa
// de print ou log e "Duvida" nao.
const requireAttachment = ref(false);
// Aparece no select da Area do Cliente. Categoria e por Mesa, e as mesmas seis
// existem em cada uma - sem esta marca, cada nome se repetia uma vez por Mesa na
// lista do cliente. Aqui se escolhe QUAL "Erro" ele ve.
const clientVisible = ref(false);
// Estagio sugerido ao fechar um ticket desta Categoria (TicketCloseDialog
// preenche Mesa + Estagio automaticamente ao escolher a Categoria, editavel
// antes de confirmar) e cor do selo no Kanban - pedido da Ingrid, 2026-11-16.
const defaultTicketColumnId = ref('');
const color = ref('');
const isSaving = ref(false);

// Mesmas cores que o WootLabel aceita (Label.vue) - reaproveitado pro selo
// da Categoria no card do Kanban, sem paleta nova.
const COLOR_OPTIONS = ['slate', 'amber', 'teal', 'ruby', 'blue', 'iris'];

// Categories are scoped to the Mesa, exactly like the Estagios above.
const categories = computed(
  () => getters['ticketColumns/getCategories'].value(props.teamId) || []
);

// Estagios da mesma Mesa da Categoria - o padrao sugerido tem que ser um
// deles, senao a Mesa (a da propria Categoria) e o Estagio nunca bateriam.
const stageOptions = computed(
  () => getters['ticketColumns/getColumns'].value(props.teamId) || []
);

const headers = computed(() => [
  t('TICKET.SETTINGS.CATEGORIES.NAME'),
  t('TICKET.SETTINGS.CATEGORIES.REQUIRE_ATTACHMENT_COLUMN'),
  t('TICKET.SETTINGS.CATEGORIES.CLIENT_VISIBLE_COLUMN'),
  t('TICKET.SETTINGS.TABLE.ACTIONS'),
]);

const openForm = category => {
  editing.value = category || null;
  name.value = category?.name || '';
  requireAttachment.value = Boolean(category?.require_attachment);
  clientVisible.value = Boolean(category?.client_visible);
  defaultTicketColumnId.value = category?.default_ticket_column_id || '';
  color.value = category?.color || '';
  formDialog.value?.open();
};

const save = async () => {
  const trimmed = name.value.trim();
  if (!trimmed || isSaving.value) return;

  isSaving.value = true;
  try {
    const payload = {
      name: trimmed,
      require_attachment: requireAttachment.value,
      client_visible: clientVisible.value,
      default_ticket_column_id: defaultTicketColumnId.value || null,
      color: color.value || null,
    };
    const action = editing.value
      ? store.dispatch('ticketColumns/updateCategory', {
          teamId: props.teamId,
          categoryId: editing.value.id,
          ...payload,
        })
      : store.dispatch('ticketColumns/createCategory', {
          teamId: props.teamId,
          ...payload,
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
    if (teamId) {
      store.dispatch('ticketColumns/fetchCategories', teamId);
      store.dispatch('ticketColumns/fetchColumns', teamId);
    }
  },
  { immediate: true }
);
</script>

<template>
  <section class="flex flex-col gap-3 min-w-0">
    <div class="flex justify-end min-w-0">
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
              <span class="inline-flex items-center gap-2 text-body-main text-n-slate-12">
                <WootLabel v-if="category.color" :label="category.name" :color="category.color" compact />
                <template v-else>{{ category.name }}</template>
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span
                v-if="category.require_attachment"
                class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md text-n-amber-11 bg-n-alpha-2"
              >
                <Icon icon="i-lucide-paperclip" class="size-3" />
                {{ t('TICKET.SETTINGS.CATEGORIES.REQUIRED_BADGE') }}
              </span>
              <span v-else class="text-sm text-n-slate-10">—</span>
            </BaseTableCell>
            <BaseTableCell>
              <span
                v-if="category.client_visible"
                class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md text-n-teal-11 bg-n-alpha-2"
              >
                <Icon icon="i-lucide-eye" class="size-3" />
                {{ t('TICKET.SETTINGS.CATEGORIES.CLIENT_VISIBLE_BADGE') }}
              </span>
              <span v-else class="text-sm text-n-slate-10">—</span>
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

      <!-- Exigir anexo na abertura. Vale para os dois formularios: o do agente
           e o da Area do Cliente. -->
      <label class="flex items-start gap-2 mt-4 cursor-pointer">
        <input v-model="requireAttachment" type="checkbox" class="mt-1 mb-0" />
        <span class="flex flex-col">
          <span class="text-sm text-n-slate-12">
            {{ t('TICKET.SETTINGS.CATEGORIES.REQUIRE_ATTACHMENT') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SETTINGS.CATEGORIES.REQUIRE_ATTACHMENT_HELP') }}
          </span>
        </span>
      </label>

      <!-- Qual Categoria o cliente ve. Como as mesmas existem em cada Mesa, e
           aqui que se escolhe qual delas recebe o chamado vindo de fora. -->
      <label class="flex items-start gap-2 mt-4 cursor-pointer">
        <input v-model="clientVisible" type="checkbox" class="mt-1 mb-0" />
        <span class="flex flex-col">
          <span class="text-sm text-n-slate-12">
            {{ t('TICKET.SETTINGS.CATEGORIES.CLIENT_VISIBLE') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SETTINGS.CATEGORIES.CLIENT_VISIBLE_HELP') }}
          </span>
        </span>
      </label>

      <!-- Estagio sugerido ao fechar um ticket desta Categoria - o
           TicketCloseDialog preenche Mesa (a da propria Categoria) + este
           Estagio automaticamente, editavel antes de confirmar. -->
      <label class="flex flex-col gap-1 mt-4">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CATEGORIES.DEFAULT_STAGE') }}
        </span>
        <select v-model="defaultTicketColumnId" class="w-full mb-0">
          <option value="">{{ t('TICKET.SETTINGS.CATEGORIES.DEFAULT_STAGE_NONE') }}</option>
          <option v-for="stage in stageOptions" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
        <span class="text-xs text-n-slate-11">
          {{ t('TICKET.SETTINGS.CATEGORIES.DEFAULT_STAGE_HELP') }}
        </span>
      </label>

      <!-- Cor do selo desta Categoria no card do Kanban. -->
      <div class="flex flex-col gap-1 mt-4">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.SETTINGS.CATEGORIES.COLOR') }}
        </span>
        <div class="flex items-center flex-wrap gap-2">
          <button
            v-for="option in COLOR_OPTIONS"
            :key="option"
            type="button"
            class="rounded-full size-7 border-2 transition-colors"
            :class="[
              `bg-n-${option}-9`,
              color === option ? 'border-n-slate-12' : 'border-transparent',
            ]"
            :aria-label="option"
            @click="color = color === option ? '' : option"
          />
        </div>
      </div>
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
