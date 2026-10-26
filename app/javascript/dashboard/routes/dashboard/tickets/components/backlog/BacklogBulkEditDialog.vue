<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketSelect from '../TicketSelect.vue';

const props = defineProps({
  tickets: { type: Array, required: true },
  columns: { type: Array, default: () => [] },
  sprints: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  isSubmitting: { type: Boolean, default: false },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();

const dialogRef = ref(null);

// Sentinela: o campo nao muda pra nenhum ticket - e' o estado inicial de
// todos os campos, igual o "Manter como está" do Jira. So' os campos que
// saem dele entram no PATCH ao confirmar.
const KEEP = '__keep__';
// Sentinela pra "esvaziar o campo" (Backlog/Ninguem) - `TicketSelect` reserva
// `null` pro mecanismo de `clearable`, que nao estamos usando aqui; um `null`
// solto na lista de opcoes faz o botao "esquecer" o rotulo escolhido e voltar
// a mostrar o placeholder. Convertido de volta pra `null` so' ao confirmar.
const CLEAR = '__clear__';

const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

const form = reactive({
  columnId: KEEP,
  sprintId: KEEP,
  priority: KEEP,
  assigneeId: KEEP,
});

const resetForm = () => {
  form.columnId = KEEP;
  form.sprintId = KEEP;
  form.priority = KEEP;
  form.assigneeId = KEEP;
};

watch(() => props.tickets, resetForm);

const ticketNumbers = computed(() =>
  props.tickets.map(ticket => `#${ticket.display_id}`).join(', ')
);

const columnOptions = computed(() => [
  { value: KEEP, label: t('TICKET.BACKLOG.BULK_EDIT.KEEP') },
  ...props.columns.map(column => ({ value: column.id, label: column.name })),
]);

const sprintOptions = computed(() => [
  { value: KEEP, label: t('TICKET.BACKLOG.BULK_EDIT.KEEP') },
  { value: CLEAR, label: t('TICKET.BACKLOG.BACKLOG_BUCKET') },
  ...props.sprints.map(sprint => ({ value: sprint.id, label: sprint.name })),
]);

const priorityOptions = computed(() => [
  { value: KEEP, label: t('TICKET.BACKLOG.BULK_EDIT.KEEP') },
  ...PRIORITIES.map(value => ({
    value,
    label: t(`TICKET.FORM.PRIORITY.${value.toUpperCase()}`),
  })),
]);

const agentOptions = computed(() => [
  { value: KEEP, label: t('TICKET.BACKLOG.BULK_EDIT.KEEP') },
  { value: CLEAR, label: t('TICKET.FORM.ASSIGNEE.NONE') },
  ...props.agents.map(agent => ({
    value: agent.id,
    label: agent.name,
    // `DropdownMenu` ja' desenha um Avatar sozinho quando o item tem
    // `thumbnail` - mesmo formato usado em `TicketMesaSelector`/`TicketCard`.
    thumbnail: { name: agent.name, src: agent.thumbnail },
  })),
]);

// So' habilita "Salvar" quando pelo menos um campo de fato saiu de "Manter
// como está" - confirmar sem mudar nada nao faria sentido.
const hasChanges = computed(
  () =>
    form.columnId !== KEEP ||
    form.sprintId !== KEEP ||
    form.priority !== KEEP ||
    form.assigneeId !== KEEP
);

const open = () => {
  resetForm();
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();

// `undefined` = nao mexer no campo; `null` = esvaziar; outro valor = o novo
// valor. `CLEAR` so' existe pro TicketSelect mostrar o rotulo certo - aqui
// vira `null` de verdade, o que `sprint_id`/`assignee_id` esperam.
const resolveField = value => {
  if (value === KEEP) return undefined;
  if (value === CLEAR) return null;
  return value;
};

const handleConfirm = () => {
  if (!hasChanges.value) return;

  emit('confirm', {
    columnId: resolveField(form.columnId),
    sprintId: resolveField(form.sprintId),
    priority: resolveField(form.priority),
    assigneeId: resolveField(form.assigneeId),
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('TICKET.BACKLOG.BULK_EDIT.TITLE')"
    :description="
      t('TICKET.BACKLOG.BULK_EDIT.DESCRIPTION', { count: tickets.length })
    "
    :confirm-button-label="t('TICKET.BACKLOG.BULK_EDIT.CONFIRM')"
    :disable-confirm-button="!hasChanges"
    :is-loading="isSubmitting"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <p class="text-sm text-n-slate-11 truncate" :title="ticketNumbers">
        {{ ticketNumbers }}
      </p>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.DETAIL.PROPERTIES.STAGE') }}
        </span>
        <TicketSelect
          v-model="form.columnId"
          :options="columnOptions"
          :aria-label="t('TICKET.DETAIL.PROPERTIES.STAGE')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.BACKLOG.BULK_MOVE_TO_SPRINT') }}
        </span>
        <TicketSelect
          v-model="form.sprintId"
          :options="sprintOptions"
          :aria-label="t('TICKET.BACKLOG.BULK_MOVE_TO_SPRINT')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.FORM.PRIORITY.LABEL') }}
        </span>
        <TicketSelect
          v-model="form.priority"
          :options="priorityOptions"
          :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.FORM.ASSIGNEE.LABEL') }}
        </span>
        <TicketSelect
          v-model="form.assigneeId"
          :options="agentOptions"
          open-upward
          :aria-label="t('TICKET.FORM.ASSIGNEE.LABEL')"
        />
      </label>
    </div>
  </Dialog>
</template>
