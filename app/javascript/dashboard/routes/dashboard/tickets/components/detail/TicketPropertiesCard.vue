<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TicketPropertyRow from './TicketPropertyRow.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  columns: { type: Array, default: () => [] },
  // Categories of this ticket's own Mesa, the same rule the stages follow.
  categories: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  canUpdate: { type: Boolean, default: true },
});
const emit = defineEmits(['updateProperty', 'moveToColumn', 'changeStatus']);
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
// `cancelled` is terminal and distinct from `closed` - a closed ticket was
// dealt with, a cancelled one never will be.
const STATUSES = ['open', 'resolved', 'closed', 'cancelled'];

// The API returns the raw `Channel::` class name; nobody wants to read
// "Channel::WebWidget" as the origin of a ticket.
const CHANNEL_LABELS = {
  [INBOX_TYPES.WEB]: 'Webchat',
  [INBOX_TYPES.FB]: 'Facebook',
  [INBOX_TYPES.TWITTER]: 'X',
  [INBOX_TYPES.TWILIO]: 'SMS',
  [INBOX_TYPES.WHATSAPP]: 'WhatsApp',
  [INBOX_TYPES.API]: 'API',
  [INBOX_TYPES.EMAIL]: 'E-mail',
  [INBOX_TYPES.TELEGRAM]: 'Telegram',
  [INBOX_TYPES.LINE]: 'LINE',
  [INBOX_TYPES.SMS]: 'SMS',
  [INBOX_TYPES.INSTAGRAM]: 'Instagram',
  [INBOX_TYPES.TIKTOK]: 'TikTok',
};

const { t } = useI18n();

const selectClass = computed(() => [
  'w-full h-9 px-2 rounded-lg border border-n-strong bg-transparent text-sm text-n-slate-12',
  'disabled:opacity-50 disabled:cursor-not-allowed',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand',
]);

const selectedAgent = computed(() =>
  props.agents.find(agent => agent.id === props.ticket.assignee_id)
);

const followers = computed(() => props.ticket.followers || []);

// A ticket opened straight from the Kanban has no conversation, so its origin
// is manual rather than a channel.
const origin = computed(() => {
  const conversation = (props.ticket.conversations || [])[0];
  if (!conversation) return t('TICKET.DETAIL.ORIGIN.MANUAL');
  return (
    conversation.inbox_name ||
    CHANNEL_LABELS[conversation.channel] ||
    conversation.channel ||
    '—'
  );
});

const createdAt = computed(() =>
  props.ticket.created_at
    ? new Date(props.ticket.created_at * 1000).toLocaleString()
    : '—'
);

const onPriority = event =>
  emit('updateProperty', { priority: event.target.value || null });

const onStatus = event => emit('changeStatus', event.target.value);

const onColumn = event => emit('moveToColumn', Number(event.target.value));

// Persisted straight away, like the other properties; the backend also refuses
// a Categoria that belongs to another Mesa.
const onCategory = event => {
  const value = event.target.value;
  emit('updateProperty', { ticket_category_id: value ? Number(value) : null });
};

const onAssignee = event => {
  const value = event.target.value;
  emit('updateProperty', { assignee_id: value ? Number(value) : null });
};
</script>

<template>
  <!-- One card rather than four: everything an agent operates on the ticket is
       here, and Seguidores and Origem sit at the foot of it instead of taking
       cards of their own. -->
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-4 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.PROPERTIES.TITLE') }}
    </h2>

    <!-- Mesa is read-only here: moving a ticket between Mesas means moving it
         into a stage of that Mesa, which the Kanban owns. -->
    <TicketPropertyRow :label="t('TICKET.SETTINGS.MESA_LABEL')">
      <span class="text-sm truncate text-n-slate-12" :title="ticket.team_name">
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
        <option v-for="priority in PRIORITIES" :key="priority" :value="priority">
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

    <!-- Only categories of this ticket's own Mesa. Distinct from the Catalogo
         de Servicos, which classifies the attendance. -->
    <TicketPropertyRow :label="t('TICKET.CREATE.CATEGORY')">
      <select
        :value="ticket.ticket_category_id || ''"
        :class="selectClass"
        :disabled="!canUpdate || !categories.length"
        :aria-label="t('TICKET.CREATE.CATEGORY')"
        @change="onCategory"
      >
        <option value="">{{ t('TICKET.DETAIL.PROPERTIES.NO_CATEGORY') }}</option>
        <option v-for="category in categories" :key="category.id" :value="category.id">
          {{ category.name }}
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

    <div class="h-px bg-n-weak" />

    <!-- Read-only context, side by side on anything but a phone. -->
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 min-w-0">
      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-xs tracking-wide uppercase text-n-slate-10">
          {{ t('TICKET.DETAIL.FOLLOWERS.TITLE') }}
        </span>
        <span
          v-if="followers.length"
          class="text-sm truncate text-n-slate-12"
          :title="followers.map(follower => follower.name).join(', ')"
        >
          {{ followers.map(follower => follower.name).join(', ') }}
        </span>
        <span v-else class="text-sm text-n-slate-10">
          {{ t('TICKET.DETAIL.FOLLOWERS.EMPTY') }}
        </span>
      </div>

      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-xs tracking-wide uppercase text-n-slate-10">
          {{ t('TICKET.DETAIL.ORIGIN.TITLE') }}
        </span>
        <span class="text-sm text-n-slate-12">{{ createdAt }}</span>
        <span class="text-sm truncate text-n-slate-11" :title="origin">
          {{ origin }}
        </span>
        <span
          v-if="ticket.created_by"
          class="text-sm truncate text-n-slate-11"
          :title="ticket.created_by.name"
        >
          {{ ticket.created_by.name }}
        </span>
      </div>
    </div>
  </section>
</template>
