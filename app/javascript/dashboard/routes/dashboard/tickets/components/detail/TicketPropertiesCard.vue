<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatMesaName } from 'dashboard/helper/mesaName';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TicketPropertyRow from './TicketPropertyRow.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  canUpdate: { type: Boolean, default: true },
});
const emit = defineEmits(['updateProperty', 'moveToColumn', 'changeStatus']);
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
const STATUSES = ['open', 'resolved', 'closed'];

const { t } = useI18n();

const selectClass = computed(() => [
  'w-full h-9 px-2 rounded-lg border border-n-strong bg-transparent text-sm text-n-slate-12',
  'disabled:opacity-50 disabled:cursor-not-allowed',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand',
]);

const selectedAgent = computed(() =>
  props.agents.find(agent => agent.id === props.ticket.assignee_id)
);

const onPriority = event =>
  emit('updateProperty', { priority: event.target.value || null });

const onStatus = event => emit('changeStatus', event.target.value);

const onColumn = event => emit('moveToColumn', Number(event.target.value));

const onAssignee = event => {
  const value = event.target.value;
  emit('updateProperty', { assignee_id: value ? Number(value) : null });
};
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-4 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.PROPERTIES.TITLE') }}
    </h2>

    <!-- Mesa is read-only here: moving a ticket between Mesas means moving it
         into a stage of that Mesa, which the Kanban owns. -->
    <TicketPropertyRow :label="t('TICKET.SETTINGS.MESA_LABEL')">
      <span class="text-sm text-n-slate-12 truncate" :title="ticket.team_name">
        {{ formatMesaName(ticket.team_name) }}
      </span>
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.FORM.PRIORITY.LABEL')">
      <select
        :value="ticket.priority || ''"
        :class="selectClass"
        :disabled="!canUpdate"
        :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
        @change="onPriority"
      >
        <option value="">{{ t('TICKET.FORM.PRIORITY.NONE') }}</option>
        <option
          v-for="priority in PRIORITIES"
          :key="priority"
          :value="priority"
        >
          {{ t(`TICKET.FORM.PRIORITY.${priority.toUpperCase()}`) }}
        </option>
      </select>
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.STATUS')">
      <select
        :value="ticket.status"
        :class="selectClass"
        :disabled="!canUpdate"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.STATUS')"
        @change="onStatus"
      >
        <option v-for="status in STATUSES" :key="status" :value="status">
          {{ t(`TICKET.STATUS.${status.toUpperCase()}`) }}
        </option>
      </select>
    </TicketPropertyRow>

    <!-- Only stages of this ticket's own Mesa. -->
    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.STAGE')">
      <select
        :value="ticket.ticket_column_id"
        :class="selectClass"
        :disabled="!canUpdate || !columns.length"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.STAGE')"
        @change="onColumn"
      >
        <option v-for="column in columns" :key="column.id" :value="column.id">
          {{ column.name }}
        </option>
      </select>
    </TicketPropertyRow>

    <!-- Members of the Mesa, not every agent in the account. -->
    <TicketPropertyRow :label="t('TICKET.FORM.ASSIGNEE.LABEL')">
      <div class="flex items-center gap-2 min-w-0">
        <Avatar
          v-if="selectedAgent"
          :name="selectedAgent.name"
          :src="selectedAgent.thumbnail"
          :size="24"
          rounded-full
          hide-offline-status
          class="flex-shrink-0"
        />
        <select
          :value="ticket.assignee_id || ''"
          :class="selectClass"
          :disabled="!canUpdate"
          :aria-label="t('TICKET.FORM.ASSIGNEE.LABEL')"
          @change="onAssignee"
        >
          <option value="">{{ t('TICKET.FORM.ASSIGNEE.NONE') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </div>
      <p v-if="!agents.length" class="text-xs text-n-slate-10">
        {{ t('TICKET.FILTERS.NO_MESA_MEMBERS') }}
      </p>
    </TicketPropertyRow>
  </section>
</template>
