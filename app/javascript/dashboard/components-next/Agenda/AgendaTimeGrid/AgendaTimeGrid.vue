<script setup>
import { computed } from 'vue';
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

const emit = defineEmits(['slot-click', 'event-click']);

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
</script>

<template>
  <div class="flex flex-1 min-h-0 overflow-y-auto">
    <div class="sticky left-0 flex-shrink-0 w-14 bg-n-background z-10">
      <div
        v-for="label in hourLabels"
        :key="label"
        class="text-right pr-2 text-xs text-n-slate-10 -translate-y-2"
        :style="{ height: `${HOUR_HEIGHT_PX}px` }"
      >
        {{ label }}
      </div>
    </div>
    <div class="flex flex-1">
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
      />
    </div>
  </div>
</template>
