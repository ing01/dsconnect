<script setup>
import { computed } from 'vue';
import { format, isToday as isDateToday } from 'date-fns';
import { buildWeekDays, isAllDayEvent } from '../helpers/agendaDateHelper';
import AgendaAllDayRow from '../AgendaTimeGrid/AgendaAllDayRow.vue';
import AgendaTimeGrid from '../AgendaTimeGrid/AgendaTimeGrid.vue';

const props = defineProps({
  referenceDate: {
    type: Date,
    required: true,
  },
  events: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['create-event', 'open-event']);

const days = computed(() => buildWeekDays(props.referenceDate));
const allDayEvents = computed(() => props.events.filter(isAllDayEvent));
const timedEvents = computed(() => props.events.filter(event => !isAllDayEvent(event)));

const handleSlotClick = date => emit('create-event', { start: date });
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div class="grid pl-14" :style="{ gridTemplateColumns: `repeat(${days.length}, minmax(0, 1fr))` }">
      <div
        v-for="day in days"
        :key="day.toISOString()"
        class="py-1.5 text-center border-r border-n-weak last:border-r-0"
      >
        <span class="text-xs text-n-slate-11">{{ format(day, 'EEE') }}</span>
        <span
          class="ml-1 text-sm font-medium"
          :class="isDateToday(day) ? 'text-n-blue-11' : 'text-n-slate-12'"
        >
          {{ format(day, 'd') }}
        </span>
      </div>
    </div>

    <div class="pl-14">
      <AgendaAllDayRow :days="days" :events="allDayEvents" @open-event="event => emit('open-event', event)" />
    </div>

    <AgendaTimeGrid
      :days="days"
      :events="timedEvents"
      @slot-click="handleSlotClick"
      @event-click="event => emit('open-event', event)"
    />
  </div>
</template>
