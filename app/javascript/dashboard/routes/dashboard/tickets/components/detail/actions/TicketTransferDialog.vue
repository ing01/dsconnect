<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

import TicketSelect from '../../TicketSelect.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);

const teamId = ref(null);
const ticketColumnId = ref(null);
const status = ref('open');
const priority = ref('medium');
const assigneeId = ref(null);

const teams = useMapGetter('teams/getTeams');

// The Estagio and the Responsavel both come FROM the selected Mesa, not from
// the ticket's current one - that is the whole point of the guided order. Both
// lists are keyed on `teamId`, so changing the Mesa changes what they offer.
const columns = computed(
  () => store.getters['ticketColumns/getColumns'](teamId.value) || []
);
const agents = computed(
  () => store.getters['teamMembers/getTeamMembers'](teamId.value) || []
);

const STATUSES = ['open', 'resolved', 'closed', 'cancelled'];
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

// As listas no formato do TicketSelect, o seletor padrao do modulo.
const teamOptions = computed(() =>
  teams.value.map(team => ({ value: team.id, label: team.name }))
);
const columnOptions = computed(() =>
  columns.value.map(column => ({ value: column.id, label: column.name }))
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const statusOptions = computed(() =>
  STATUSES.map(value => ({
    value,
    label: t(`TICKET.STATUS.${value.toUpperCase()}`),
  }))
);
const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({
    value,
    label: t(`TICKET.FORM.PRIORITY.${value.toUpperCase()}`),
  }))
);

const reset = () => {
  teamId.value = props.ticket.team_id;
  ticketColumnId.value = props.ticket.ticket_column_id;
  status.value = props.ticket.status;
  priority.value = props.ticket.priority || 'medium';
  assigneeId.value = props.ticket.assignee_id ?? null;
};

const loadMesaContext = id => {
  if (!id) return;
  store.dispatch('teamMembers/get', { teamId: id });
  store.dispatch('ticketColumns/fetchColumns', id);
};

// Switching Mesa invalidates both dependent choices. Clearing them (rather than
// keeping a stale id) is what stops the form submitting an Estagio that belongs
// to another Mesa, which the server would reject anyway.
watch(teamId, (id, previous) => {
  loadMesaContext(id);
  if (previous == null || id === previous) return;
  ticketColumnId.value = null;
  assigneeId.value = null;
});

// The first Estagio of the newly chosen Mesa is a better default than an empty
// select, since a ticket cannot exist without one.
watch(columns, list => {
  if (!ticketColumnId.value && list.length) ticketColumnId.value = list[0].id;
});

const isValid = computed(() => !!teamId.value && !!ticketColumnId.value);

const open = () => {
  reset();
  loadMesaContext(props.ticket.team_id);
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (!isValid.value) return;
  emit('submit', {
    team_id: teamId.value,
    ticket_column_id: ticketColumnId.value,
    status: status.value,
    priority: priority.value,
    assignee_id: assigneeId.value == null ? null : Number(assigneeId.value),
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    overflow-y-auto
    :title="t('TICKET.ACTIONS.TRANSFER_DIALOG.TITLE')"
    :confirm-button-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.CONFIRM')"
    :disable-confirm-button="!isValid"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.TEAM') }}
        </span>
        <TicketSelect
          v-model="teamId"
          :options="teamOptions"
          :aria-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.TEAM')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.COLUMN') }}
        </span>
        <TicketSelect
          v-model="ticketColumnId"
          :options="columnOptions"
          :disabled="!columns.length"
          :aria-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.COLUMN')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.STATUS') }}
        </span>
        <TicketSelect
          v-model="status"
          :options="statusOptions"
          :aria-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.STATUS')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.PRIORITY') }}
        </span>
        <TicketSelect
          v-model="priority"
          :options="priorityOptions"
          :aria-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.PRIORITY')"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.ASSIGNEE') }}
        </span>
        <TicketSelect
          v-model="assigneeId"
          :options="agentOptions"
          clearable
          :clear-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.UNASSIGNED')"
          :placeholder="t('TICKET.ACTIONS.TRANSFER_DIALOG.UNASSIGNED')"
          :aria-label="t('TICKET.ACTIONS.TRANSFER_DIALOG.ASSIGNEE')"
        />
        <span v-if="!agents.length" class="text-xs text-n-slate-10">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.NO_MEMBERS') }}
        </span>
      </label>
    </div>
  </Dialog>
</template>
