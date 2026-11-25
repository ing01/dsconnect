<script setup>
import { computed } from 'vue';
import { format, parseISO } from 'date-fns';
import { colorForEvent, eventSurfaceStyle } from '../helpers/agentColorHelper';
import {
  isAllDayEvent,
  isPastDayEvent,
  isTimeOffEvent,
} from '../helpers/agendaDateHelper';

const props = defineProps({
  event: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);

const color = computed(() => colorForEvent(props.event));
const isTimeOff = computed(() => isTimeOffEvent(props.event));
const isPast = computed(() => isPastDayEvent(props.event));

// Mesmo visual do bloco da semana/dia (estilo Outlook): titulo primeiro,
// quebrando linha, e o horario pequeno embaixo. Evento de dia inteiro/varios
// dias nao tem horario a mostrar.
const timeLabel = computed(() =>
  isAllDayEvent(props.event)
    ? ''
    : `${format(parseISO(props.event.start_at), 'HH:mm')}–${format(parseISO(props.event.end_at), 'HH:mm')}`
);

const handleClick = e => {
  e.stopPropagation();
  emit('click');
};
</script>

<template>
  <button
    type="button"
    class="flex flex-col items-start w-full pl-1.5 pr-1 py-0.5 rounded border-l-4 text-left text-white hover:brightness-125 transition"
    :class="{
      'opacity-50': isPast,
      'outline-dashed outline-1 -outline-offset-1 outline-white/50': isTimeOff,
    }"
    :style="eventSurfaceStyle(color)"
    :title="timeLabel ? `${event.title} (${timeLabel})` : event.title"
    @click="handleClick"
  >
    <span
      class="flex items-start gap-1 w-full text-xs font-semibold leading-tight whitespace-normal break-words"
    >
      <span v-if="isTimeOff" class="shrink-0 mt-px i-lucide-palmtree size-3" />
      <span class="flex-1 min-w-0">{{ event.title }}</span>
      <span
        v-if="event.tickets?.length"
        class="shrink-0 mt-px i-lucide-ticket size-3"
      />
    </span>
    <span v-if="timeLabel" class="block w-full text-[10px] opacity-80 truncate">
      {{ timeLabel }}
    </span>
  </button>
</template>
