<script>
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const PRIORITY_COLORS = {
  low: 'slate',
  medium: 'blue',
  high: 'amber',
  urgent: 'ruby',
};

export default {
  components: {
    WootLabel,
    Icon,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    agents: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['click'],
  computed: {
    priorityColor() {
      return PRIORITY_COLORS[this.ticket.priority] || 'slate';
    },
    priorityLabel() {
      return this.ticket.priority
        ? this.$t(`TICKET.FORM.PRIORITY.${this.ticket.priority.toUpperCase()}`)
        : '';
    },
    assigneeName() {
      const agent = this.agents.find(a => a.id === this.ticket.assignee_id);
      return agent?.name || '';
    },
    conversationCount() {
      return this.ticket.conversation_ids?.length || 0;
    },
  },
};
</script>

<template>
  <div
    class="drag-handle group flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3 cursor-pointer hover:border-n-slate-6 hover:shadow-sm transition-shadow"
    @click="$emit('click', ticket)"
  >
    <p class="text-sm font-medium text-n-slate-12 line-clamp-2">
      {{ ticket.title }}
    </p>

    <div class="flex items-center justify-between gap-2">
      <WootLabel
        v-if="ticket.priority"
        :label="priorityLabel"
        :color="priorityColor"
        compact
      />
      <span v-else class="text-xs text-n-slate-10">
        {{ $t('TICKET.FORM.PRIORITY.NONE') }}
      </span>

      <div
        v-if="conversationCount"
        class="flex items-center gap-1 text-xs text-n-slate-11"
      >
        <Icon icon="i-lucide-message-circle" class="size-3.5" />
        {{ conversationCount }}
      </div>
    </div>

    <div v-if="assigneeName" class="flex items-center gap-1.5">
      <span
        class="flex size-5 items-center justify-center rounded-full bg-n-slate-4 text-[10px] font-medium text-n-slate-12"
      >
        {{ assigneeName.charAt(0).toUpperCase() }}
      </span>
      <span class="text-xs text-n-slate-11 truncate">{{ assigneeName }}</span>
    </div>
  </div>
</template>
