<script setup>
import { computed, onMounted, ref } from 'vue';
import { format, addHours, startOfDay } from 'date-fns';
import { HOUR_HEIGHT_PX, DAY_START_HOUR, DAY_END_HOUR } from '../constants';
import AgendaTimeGridColumn from './AgendaTimeGridColumn.vue';

const props = defineProps({
  days: {
    type: Array,
    required: true,
  },
  events: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['slot-click', 'event-click', 'event-drag-end']);

const scrollEl = ref(null);

const hourLabels = computed(() =>
  Array.from({ length: DAY_END_HOUR - DAY_START_HOUR }, (_, i) =>
    format(addHours(startOfDay(new Date()), DAY_START_HOUR + i), 'HH:mm')
  )
);

const eventsFor = day =>
  props.events.filter(event => {
    const start = new Date(event.start_at);
    const end = new Date(event.end_at);
    return start < addHours(startOfDay(day), DAY_END_HOUR) && end > addHours(startOfDay(day), DAY_START_HOUR);
  });

onMounted(() => {
  if (!scrollEl.value) return;
  const now = new Date();
  const minutesFromStart = (now.getHours() - DAY_START_HOUR) * 60 + now.getMinutes();
  const nowTopPx = (minutesFromStart / 60) * HOUR_HEIGHT_PX;
  // Centraliza o horário atual na área visível; clampado a 0 para não rolar pra cima do início.
  scrollEl.value.scrollTop = Math.max(0, nowTopPx - scrollEl.value.clientHeight / 2);
});
</script>

<template>
  <div ref="scrollEl" class="flex flex-1 min-h-0 min-w-0 overflow-y-auto overflow-x-hidden">
    <div class="sticky left-0 flex-shrink-0 w-14 pt-2 bg-n-background z-10">
      <div
        v-for="label in hourLabels"
        :key="label"
        class="text-right pr-2 text-xs text-n-slate-11 -translate-y-2"
        :style="{ height: `${HOUR_HEIGHT_PX}px` }"
      >
        {{ label }}
      </div>
    </div>
    <div class="flex flex-1 min-w-0">
      <AgendaTimeGridColumn
        v-for="day in days"
        :key="day.toISOString()"
        :day="day"
        :events="eventsFor(day)"
        :hour-height="HOUR_HEIGHT_PX"
        :day-start-hour="DAY_START_HOUR"
        :day-end-hour="DAY_END_HOUR"
        @slot-click="date => emit('slot-click', date)"
        @event-click="event => emit('event-click', event)"
        @event-drag-end="payload => emit('event-drag-end', payload)"
      />
    </div>
  </div>
</template>
