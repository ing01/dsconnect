<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO } from 'date-fns';
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
  // Quando a Mesa usa niveis, o responsavel vira Responsavel 1 e aparece um
  // campo por nivel seguinte. Sem isso a tela fica exatamente como sempre foi.
  usesAssigneeLevels: { type: Boolean, default: false },
  // Os niveis desta Mesa, ja resolvidos pelo servidor. Chega vazio nas Mesas sem
  // niveis, e ai `usesAssigneeLevels` ja mantem a tela como era.
  assigneeLevels: { type: Array, default: () => [] },
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

const toOption = agent => ({
  value: agent.id,
  label: agent.name,
  thumbnail: { name: agent.name, src: agent.thumbnail },
});

// Sem niveis, todo membro da Mesa serve. Com niveis, so quem esta habilitado
// naquele nivel - a mesma regra que o servidor valida, para a tela nao oferecer
// uma escolha que a API vai recusar.
const agentsForLevel = level =>
  props.usesAssigneeLevels
    ? props.agents.filter(agent => (agent.levels || []).includes(level))
    : props.agents;

const agentOptions = computed(() => agentsForLevel(1).map(toOption));

const selectedAgent = computed(() =>
  props.agents.find(agent => agent.id === props.ticket.assignee_id)
);

// Um campo por nivel do Nivel 2 em diante. Cada um sabe so o proprio numero: e o
// que faz um Nivel 3 aparecer ao subir a Mesa, sem codigo novo nesta tela.
const higherLevels = computed(() =>
  props.assigneeLevels.filter(level => level > 1)
);

const levelField = level => `assignee_${level}_id`;

const levelRows = computed(() =>
  higherLevels.value.map(level => ({
    level,
    label: t('TICKET.FORM.ASSIGNEE.LEVEL', { level }),
    value: props.ticket[levelField(level)] || null,
    options: agentsForLevel(level).map(toOption),
    selected: props.agents.find(
      agent => agent.id === props.ticket[levelField(level)]
    ),
  }))
);

// O rotulo muda de "Responsavel" para "Responsavel 1" so onde ha niveis.
const firstAssigneeLabel = computed(() =>
  props.usesAssigneeLevels
    ? t('TICKET.FORM.ASSIGNEE.LEVEL', { level: 1 })
    : t('TICKET.FORM.ASSIGNEE.LABEL')
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
const onCategory = value =>
  emit('updateProperty', { ticket_category_id: value ? Number(value) : null });

const onAssignee = value =>
  emit('updateProperty', { assignee_id: value ? Number(value) : null });

const onLevelAssignee = (level, value) =>
  emit('updateProperty', {
    [levelField(level)]: value ? Number(value) : null,
  });

// `datetime-local` reads/writes "yyyy-MM-ddTHH:mm" in the browser's own
// timezone; the API stores/returns ISO 8601. An empty string clears the field
// (Vencimento/Agendamento are both optional at the model level - only a
// column's require_due_date/require_scheduled_at rule makes them mandatory).
const toLocalInputValue = iso =>
  iso ? format(parseISO(iso), "yyyy-MM-dd'T'HH:mm") : '';

const dueDateLocal = computed(() => toLocalInputValue(props.ticket.due_date));
const scheduledAtLocal = computed(() =>
  toLocalInputValue(props.ticket.scheduled_at)
);

const onDueDate = value =>
  emit('updateProperty', {
    due_date: value ? new Date(value).toISOString() : null,
  });

const onScheduledAt = value =>
  emit('updateProperty', {
    scheduled_at: value ? new Date(value).toISOString() : null,
  });
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

    <!-- Members of the Mesa, not every agent in the account. -->
    <TicketPropertyRow :label="firstAssigneeLabel">
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
          :aria-label="firstAssigneeLabel"
          @update:model-value="onAssignee"
        />
      </div>
      <p v-if="!agents.length" class="text-xs text-n-slate-10">
        {{ t('TICKET.FILTERS.NO_MESA_MEMBERS') }}
      </p>
    </TicketPropertyRow>

    <!-- Os niveis acima do primeiro so existem onde a Mesa usa niveis, e cada um
         pode ficar vazio enquanto o ticket nao for escalado ate ele. -->
    <TicketPropertyRow
      v-for="row in levelRows"
      :key="row.level"
      :label="row.label"
    >
      <div class="flex items-center gap-2 min-w-0">
        <Avatar
          v-if="row.selected"
          :name="row.selected.name"
          :src="row.selected.thumbnail"
          :size="24"
          rounded-full
          hide-offline-status
          class="flex-shrink-0"
        />
        <TicketSelect
          :model-value="row.value"
          :options="row.options"
          :disabled="!canUpdate"
          clearable
          :clear-label="t('TICKET.FORM.ASSIGNEE.NONE')"
          :placeholder="t('TICKET.FORM.ASSIGNEE.NONE')"
          :aria-label="row.label"
          @update:model-value="value => onLevelAssignee(row.level, value)"
        />
      </div>
      <p v-if="!row.options.length" class="text-xs text-n-slate-10">
        {{ t('TICKET.FORM.ASSIGNEE.NO_LEVEL_MEMBERS') }}
      </p>
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.DUE_DATE')">
      <input
        type="datetime-local"
        :value="dueDateLocal"
        :disabled="!canUpdate"
        class="h-9 w-full px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
        @change="onDueDate($event.target.value)"
      />
    </TicketPropertyRow>

    <TicketPropertyRow :label="t('TICKET.DETAIL.PROPERTIES.SCHEDULED_AT')">
      <input
        type="datetime-local"
        :value="scheduledAtLocal"
        :disabled="!canUpdate"
        class="h-9 w-full px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
        @change="onScheduledAt($event.target.value)"
      />
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
