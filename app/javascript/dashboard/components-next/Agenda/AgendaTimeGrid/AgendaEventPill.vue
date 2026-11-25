<script setup>
import { computed } from 'vue';
import { format, parseISO } from 'date-fns';
import { colorForEvent } from '../helpers/agentColorHelper';
import { isAllDayEvent, isTimeOffEvent } from '../helpers/agendaDateHelper';

const props = defineProps({
  event: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);

const color = computed(() => colorForEvent(props.event));
const isTimeOff = computed(() => isTimeOffEvent(props.event));

// O horario vem antes do titulo (no mes, a pilula era so' o titulo cortado, e
// o horario nao aparecia em lugar nenhum). Evento de dia inteiro/varios dias
// nao tem horario a mostrar.
const timeLabel = computed(() =>
  isAllDayEvent(props.event)
    ? ''
    : `${format(parseISO(props.event.start_at), 'HH:mm')} - ${format(parseISO(props.event.end_at), 'HH:mm')}`
);

const handleClick = e => {
  e.stopPropagation();
  emit('click');
};
</script>

<template>
  <button
    type="button"
    class="flex items-start gap-1.5 w-full px-1.5 py-0.5 rounded-md text-xs text-left text-white hover:opacity-90 transition-opacity"
    :class="{ 'border border-dashed border-white/60': isTimeOff }"
    :style="{ backgroundColor: color, opacity: isTimeOff ? 0.75 : 1 }"
    :title="timeLabel ? `${timeLabel} ${event.title}` : event.title"
    @click="handleClick"
  >
    <span v-if="isTimeOff" class="shrink-0 mt-0.5 i-lucide-palmtree size-3" />
    <span class="flex-1 min-w-0 whitespace-normal break-words leading-snug">
      <span v-if="timeLabel" class="font-semibold">{{ timeLabel }}</span>
      {{ event.title }}
    </span>
    <span
      v-if="event.tickets?.length"
      class="shrink-0 mt-0.5 i-lucide-ticket size-3"
    />
  </button>
</template>
