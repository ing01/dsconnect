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

const props = defineProps({
  ticket: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['unlink']);

const priorityColor = computed(
  () => PRIORITY_COLORS[props.ticket.priority] || 'slate'
);
</script>

<template>
  <div class="flex items-start justify-between gap-2">
    <div class="flex flex-col gap-1 min-w-0">
      <h3 class="text-sm font-medium text-n-slate-12 truncate">
        {{ ticket.title }}
      </h3>
      <WootLabel
        v-if="ticket.priority"
        :label="$t(`TICKET.FORM.PRIORITY.${ticket.priority.toUpperCase()}`)"
        :color="priorityColor"
        compact
      />
    </div>
    <NextButton
      ghost
      slate
      xs
      icon="i-lucide-x"
      @click="emit('unlink', ticket.id)"
    />
  </div>
</template>
