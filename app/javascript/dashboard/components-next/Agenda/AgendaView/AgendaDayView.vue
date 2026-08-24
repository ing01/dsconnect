<script setup>
import { computed } from 'vue';
import { isAllDayEvent } from '../helpers/agendaDateHelper';
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

const days = computed(() => [props.referenceDate]);
const allDayEvents = computed(() => props.events.filter(isAllDayEvent));
const timedEvents = computed(() => props.events.filter(event => !isAllDayEvent(event)));

const handleSlotClick = date => emit('create-event', { start: date });
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
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
