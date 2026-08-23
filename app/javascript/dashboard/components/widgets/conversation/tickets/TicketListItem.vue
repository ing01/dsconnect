<script setup>
import { computed } from 'vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const PRIORITY_COLORS = {
  low: 'slate',
  medium: 'blue',
  high: 'amber',
  urgent: 'ruby',
};

const STATUS_COLORS = {
  open: 'slate',
  resolved: 'green',
  closed: 'violet',
};

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['unlink', 'click']);

const priorityColor = computed(
  () => PRIORITY_COLORS[props.ticket.priority] || 'slate'
);
const statusColor = computed(
  () => STATUS_COLORS[props.ticket.status] || 'slate'
);
</script>

<template>
  <div class="flex items-start justify-between gap-2" @click="emit('click')">
    <div class="flex flex-col gap-1 min-w-0">
      <div class="flex items-center gap-1.5">
        <span
          v-if="ticket.display_id"
          class="text-xs font-medium text-n-slate-10"
        >
          #{{ ticket.display_id }}
        </span>
        <h3 class="text-sm font-medium text-n-slate-12 truncate">
          {{ ticket.title }}
        </h3>
      </div>
      <div class="flex items-center gap-1.5">
        <WootLabel
          v-if="ticket.status"
          :label="$t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
          :color="statusColor"
          compact
        />
        <WootLabel
          v-if="ticket.priority"
          :label="$t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`)"
          :color="priorityColor"
          compact
        />
      </div>
    </div>
    <NextButton
      ghost
      slate
      xs
      icon="i-lucide-x"
      @click.stop="emit('unlink', ticket.id)"
    />
  </div>
</template>
