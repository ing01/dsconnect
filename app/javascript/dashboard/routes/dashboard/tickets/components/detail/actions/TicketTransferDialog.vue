<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

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
const assigneeId = ref('');

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

const reset = () => {
  teamId.value = props.ticket.team_id;
  ticketColumnId.value = props.ticket.ticket_column_id;
  status.value = props.ticket.status;
  priority.value = props.ticket.priority || 'medium';
  assigneeId.value = props.ticket.assignee_id ?? '';
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
  assigneeId.value = '';
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
    assignee_id: assigneeId.value === '' ? null : Number(assigneeId.value),
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
        <select v-model="teamId" class="w-full mb-0">
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.COLUMN') }}
        </span>
        <select
          v-model="ticketColumnId"
          :disabled="!columns.length"
          class="w-full mb-0"
        >
          <option v-for="column in columns" :key="column.id" :value="column.id">
            {{ column.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.STATUS') }}
        </span>
        <select v-model="status" class="w-full mb-0">
          <option v-for="value in STATUSES" :key="value" :value="value">
            {{ t(`TICKET.STATUS.${value.toUpperCase()}`) }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.PRIORITY') }}
        </span>
        <select v-model="priority" class="w-full mb-0">
          <option v-for="value in PRIORITIES" :key="value" :value="value">
            {{ t(`TICKET.FORM.PRIORITY.${value.toUpperCase()}`) }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.ASSIGNEE') }}
        </span>
        <select v-model="assigneeId" class="w-full mb-0">
          <option value="">
            {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.UNASSIGNED') }}
          </option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
        <span v-if="!agents.length" class="text-xs text-n-slate-10">
          {{ t('TICKET.ACTIONS.TRANSFER_DIALOG.NO_MEMBERS') }}
        </span>
      </label>
    </div>
  </Dialog>
</template>
