<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatMesaName } from 'dashboard/helper/mesaName';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TicketSelect from '../TicketSelect.vue';
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

// As listas no formato do TicketSelect, o seletor padrao do modulo.
const priorityOptions = computed(() =>
  PRIORITIES.map(priority => ({
    value: priority,
    label: t(`TICKET.FORM.PRIORITY.${priority.toUpperCase()}`),
  }))
);

const statusOptions = computed(() =>
  STATUSES.map(status => ({
    value: status,
    label: t(`TICKET.STATUS.${status.toUpperCase()}`),
  }))
);

const columnOptions = computed(() =>
  props.columns.map(column => ({ value: column.id, label: column.name }))
);

const categoryOptions = computed(() =>
  props.categories.map(category => ({
    value: category.id,
    label: category.name,
  }))
);

const agentOptions = computed(() =>
  props.agents.map(agent => ({
    value: agent.id,
    label: agent.name,
    thumbnail: { name: agent.name, src: agent.thumbnail },
  }))
);

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

const onPriority = value => emit('updateProperty', { priority: value || null });

const onStatus = value => emit('changeStatus', value);

const onColumn = value => emit('moveToColumn', Number(value));

// Persisted straight away, like the other properties; the backend also refuses
// a Categoria that belongs to another Mesa.
// A data de entrega e a mesma `due_date` que os Estagios ja podem exigir e que
// os templates de projeto preenchem - nao um prazo paralelo. O input fala no
// fuso de quem olha; o servidor guarda o instante.
const dueDateInput = computed(() => {
  if (!props.ticket.due_date) return '';

  const date = new Date(props.ticket.due_date);
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return shifted.toISOString().slice(0, 16);
});

const onDueDate = event => {
  const value = event.target.value;
  emit('updateProperty', {
    due_date: value ? new Date(value).toISOString() : null,
  });
};

const onCategory = value =>
  emit('updateProperty', { ticket_category_id: value ? Number(value) : null });

const onAssignee = value =>
  emit('updateProperty', { assignee_id: value ? Number(value) : null });
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
      <TicketSelect
        :model-value="ticket.priority || null"
        :options="priorityOptions"
        :disabled="!canUpdate"
        clearable
        :clear-label="t('TICKET.FORM.PRIORITY.NONE')"
        :placeholder="t('TICKET.FORM.PRIORITY.NONE')"
        :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
        @update:model-value="onPriority"
      />
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.STATUS')">
      <TicketSelect
        :model-value="ticket.status"
        :options="statusOptions"
        :disabled="!canUpdate"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.STATUS')"
        @update:model-value="onStatus"
      />
    </TicketPropertyRow>

    <!-- Only stages of this ticket's own Mesa. -->
    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.STAGE')">
      <TicketSelect
        :model-value="ticket.ticket_column_id"
        :options="columnOptions"
        :disabled="!canUpdate || !columns.length"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.STAGE')"
        @update:model-value="onColumn"
      />
    </TicketPropertyRow>

    <!-- Only categories of this ticket's own Mesa. Distinct from the Catalogo
         de Servicos, which classifies the attendance. -->
    <TicketPropertyRow :label="t('TICKET.CREATE.CATEGORY')">
      <TicketSelect
        :model-value="ticket.ticket_category_id || null"
        :options="categoryOptions"
        :disabled="!canUpdate || !categories.length"
        clearable
        :clear-label="t('TICKET.DETAIL.PROPERTIES.NO_CATEGORY')"
        :placeholder="t('TICKET.DETAIL.PROPERTIES.NO_CATEGORY')"
        :aria-label="t('TICKET.CREATE.CATEGORY')"
        @update:model-value="onCategory"
      />
    </TicketPropertyRow>

    <!-- A data prometida de entrega. Mesmo campo que um Estagio pode exigir
         para deixar o ticket entrar nele. -->
    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.DUE_DATE')">
      <input
        :value="dueDateInput"
        type="datetime-local"
        class="w-full mb-0"
        :disabled="!canUpdate"
        :aria-label="t('TICKET.DETAIL.PROPERTIES.DUE_DATE')"
        @change="onDueDate"
      />
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
        <TicketSelect
          :model-value="ticket.assignee_id || null"
          :options="agentOptions"
          :disabled="!canUpdate"
          clearable
          :clear-label="t('TICKET.FORM.ASSIGNEE.NONE')"
          :placeholder="t('TICKET.FORM.ASSIGNEE.NONE')"
          :aria-label="t('TICKET.FORM.ASSIGNEE.LABEL')"
          @update:model-value="onAssignee"
        />
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
