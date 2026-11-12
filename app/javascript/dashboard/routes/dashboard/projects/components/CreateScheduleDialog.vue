<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import ProjectsAPI from 'dashboard/api/projects';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  projectId: { type: [Number, String], required: true },
  tickets: { type: Array, default: () => [] },
  agentOptions: { type: Array, default: () => [] },
});

const emit = defineEmits(['created']);

const { t } = useI18n();

const dialogRef = ref(null);
const isSaving = ref(false);

// Cada linha vira um CalendarEvent vinculado a um ticket (existente ou
// criado na hora) - pedido da Ingrid, 2026-11-12: "vinculando tickets e
// datas a cada agendamento". `responsible_user_id` ja' vem preenchido com o
// assignee do ticket escolhido, mas pode ser trocado linha a linha.
const emptyRow = () => ({
  ticketMode: 'existing',
  ticket_id: '',
  new_ticket_title: '',
  start_at: '',
  end_at: '',
  responsible_user_id: '',
});

const rows = ref([emptyRow()]);

const ticketOptions = computed(() => props.tickets || []);

const open = () => {
  rows.value = [emptyRow()];
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const addRow = () => rows.value.push(emptyRow());
const removeRow = index => rows.value.splice(index, 1);

const onTicketSelect = row => {
  const ticket = ticketOptions.value.find(t2 => t2.id === Number(row.ticket_id));
  row.responsible_user_id = ticket?.assignee_id || '';
};

const isRowValid = row => {
  const hasTicket = row.ticketMode === 'existing' ? !!row.ticket_id : !!row.new_ticket_title.trim();
  return hasTicket && !!row.start_at;
};

const canSave = computed(() => rows.value.some(isRowValid));

const buildItems = () =>
  rows.value.filter(isRowValid).map(row => ({
    ticket_id: row.ticketMode === 'existing' ? row.ticket_id : undefined,
    new_ticket_title: row.ticketMode === 'new' ? row.new_ticket_title.trim() : undefined,
    start_at: row.start_at,
    end_at: row.end_at || undefined,
    responsible_user_id: row.responsible_user_id || undefined,
  }));

const save = async () => {
  const items = buildItems();
  if (!items.length) return;

  isSaving.value = true;
  try {
    const { data } = await ProjectsAPI.createSchedule(props.projectId, items);
    useAlert(t('PROJECTS.SCHEDULE.SUCCESS', { count: data.created_count }));
    emit('created');
    close();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('PROJECTS.SCHEDULE.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('PROJECTS.SCHEDULE.TITLE')"
    :description="t('PROJECTS.SCHEDULE.DESCRIPTION')"
    width="2xl"
    overflow-y-auto
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex flex-col gap-3 max-h-[55vh] overflow-y-auto">
      <div
        v-for="(row, index) in rows"
        :key="index"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-1 p-0.5 rounded-lg bg-n-slate-3 w-fit">
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="row.ticketMode === 'existing' ? 'bg-n-solid-1 text-n-slate-12' : 'text-n-slate-11'"
              @click="row.ticketMode = 'existing'"
            >
              {{ t('PROJECTS.SCHEDULE.EXISTING_TICKET') }}
            </button>
            <button
              type="button"
              class="px-2 py-1 text-xs rounded-md"
              :class="row.ticketMode === 'new' ? 'bg-n-solid-1 text-n-slate-12' : 'text-n-slate-11'"
              @click="row.ticketMode = 'new'"
            >
              {{ t('PROJECTS.SCHEDULE.NEW_TICKET') }}
            </button>
          </div>
          <button
            v-if="rows.length > 1"
            type="button"
            :aria-label="t('PROJECTS.SCHEDULE.REMOVE_ROW')"
            class="text-n-slate-10 hover:text-n-ruby-11"
            @click="removeRow(index)"
          >
            <Icon icon="i-lucide-x" class="size-4" />
          </button>
        </div>

        <select
          v-if="row.ticketMode === 'existing'"
          v-model="row.ticket_id"
          class="h-9 w-full text-sm"
          @change="onTicketSelect(row)"
        >
          <option value="">{{ t('PROJECTS.SCHEDULE.SELECT_TICKET') }}</option>
          <option v-for="ticket in ticketOptions" :key="ticket.id" :value="ticket.id">
            #{{ ticket.display_id || ticket.id }} - {{ ticket.title }}
          </option>
        </select>
        <input
          v-else
          v-model="row.new_ticket_title"
          type="text"
          :placeholder="t('PROJECTS.SCHEDULE.NEW_TICKET_PLACEHOLDER')"
          class="h-9 w-full text-sm"
        />

        <div class="grid grid-cols-3 gap-2">
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.START_AT') }}
            <input v-model="row.start_at" type="datetime-local" class="h-9 w-full text-xs" />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.END_AT') }}
            <input v-model="row.end_at" type="datetime-local" class="h-9 w-full text-xs" />
          </label>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            {{ t('PROJECTS.SCHEDULE.RESPONSIBLE') }}
            <select v-model="row.responsible_user_id" class="h-9 w-full text-xs">
              <option value="">{{ t('PROJECTS.SCHEDULE.NO_RESPONSIBLE') }}</option>
              <option v-for="agent in agentOptions" :key="agent.value" :value="agent.value">
                {{ agent.label }}
              </option>
            </select>
          </label>
        </div>
      </div>

      <NextButton
        icon="i-lucide-plus"
        size="sm"
        faded
        slate
        class="w-fit"
        :label="t('PROJECTS.SCHEDULE.ADD_ROW')"
        @click="addRow"
      />
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <NextButton
          variant="faded"
          color="slate"
          type="button"
          class="w-full"
          :label="t('PROJECTS.FORM.CANCEL')"
          @click="close"
        />
        <NextButton
          type="button"
          class="w-full"
          :label="t('PROJECTS.SCHEDULE.SAVE')"
          :is-loading="isSaving"
          :disabled="!canSave || isSaving"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
