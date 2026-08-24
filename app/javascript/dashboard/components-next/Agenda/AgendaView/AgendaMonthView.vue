<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, isSameMonth, isToday as isDateToday } from 'date-fns';
import { buildMonthGrid, groupEventsByDay } from '../helpers/agendaDateHelper';
import AgendaMonthDayCell from '../AgendaMonthView/AgendaMonthDayCell.vue';

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

const emit = defineEmits(['navigate-day', 'open-event']);

const { t } = useI18n();

const weekdayLabels = computed(() =>
  Array.from({ length: 7 }, (_, i) => t(`AGENDA.WEEKDAYS_SHORT.${i}`))
);

const grid = computed(() => buildMonthGrid(props.referenceDate));
const eventsByDay = computed(() =>
  groupEventsByDay(props.events, grid.value.gridStart, grid.value.gridEnd)
);

const eventsFor = date => eventsByDay.value.get(format(date, 'yyyy-MM-dd')) || [];
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div class="grid grid-cols-7 flex-shrink-0">
      <div
        v-for="label in weekdayLabels"
        :key="label"
        class="py-2 text-xs font-medium text-center text-n-slate-11"
      >
        {{ label }}
      </div>
    </div>
    <div class="grid flex-1 grid-cols-7 overflow-y-auto" :style="{ gridTemplateRows: `repeat(${grid.weeks.length}, minmax(0, 1fr))` }">
      <AgendaMonthDayCell
        v-for="day in grid.days"
        :key="day.toISOString()"
        :date="day"
        :is-current-month="isSameMonth(day, referenceDate)"
        :is-today="isDateToday(day)"
        :events="eventsFor(day)"
        @click-day="date => emit('navigate-day', date)"
        @click-event="event => emit('open-event', event)"
      />
    </div>
  </div>
</template>
