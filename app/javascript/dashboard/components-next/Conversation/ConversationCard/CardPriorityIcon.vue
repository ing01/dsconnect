<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';

import WootLabel from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  priority: {
    type: String,
    default: '',
  },
  showEmpty: {
    type: Boolean,
    default: false,
  },
  compact: {
    type: Boolean,
    default: true,
  },
});
const { t } = useI18n();

// Mesmas cores usadas pra prioridade de Ticket (`routes/dashboard/tickets/helpers/ticketLabels.js`)
// - mantem os dois lugares do produto (tickets e conversas) com a mesma linguagem visual de cor.
const colors = {
  [CONVERSATION_PRIORITY.URGENT]: 'ruby',
  [CONVERSATION_PRIORITY.HIGH]: 'amber',
  [CONVERSATION_PRIORITY.MEDIUM]: 'blue',
  [CONVERSATION_PRIORITY.LOW]: 'slate',
};

const priorityLabels = {
  [CONVERSATION_PRIORITY.URGENT]: 'CONVERSATION.PRIORITY.OPTIONS.URGENT',
  [CONVERSATION_PRIORITY.HIGH]: 'CONVERSATION.PRIORITY.OPTIONS.HIGH',
  [CONVERSATION_PRIORITY.MEDIUM]: 'CONVERSATION.PRIORITY.OPTIONS.MEDIUM',
  [CONVERSATION_PRIORITY.LOW]: 'CONVERSATION.PRIORITY.OPTIONS.LOW',
};

const hasPriority = computed(
  () => !!(props.priority && priorityLabels[props.priority])
);

const label = computed(() => {
  if (hasPriority.value) return t(priorityLabels[props.priority]);
  return props.showEmpty ? t('CONVERSATION.PRIORITY.OPTIONS.NONE') : '';
});

const color = computed(() => colors[props.priority] || 'slate');
</script>

<template>
  <WootLabel v-if="hasPriority" :label="label" :color="color" :compact="compact" />
  <span
    v-else-if="showEmpty"
    class="text-xs text-n-slate-10 whitespace-nowrap"
  >
    {{ label }}
  </span>
</template>
