<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { groupEventsByDay } from '../helpers/agendaDateHelper';
import AgendaEventPill from './AgendaEventPill.vue';

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

const emit = defineEmits(['open-event']);

const eventsByDay = computed(() =>
  groupEventsByDay(props.events, props.days[0], props.days[props.days.length - 1])
);

const eventsFor = date => eventsByDay.value.get(format(date, 'yyyy-MM-dd')) || [];
</script>

<template>
  <div
    v-if="events.length"
    class="grid border-b border-n-weak"
    :style="{ gridTemplateColumns: `repeat(${days.length}, minmax(0, 1fr))` }"
  >
    <div
      v-for="day in days"
      :key="day.toISOString()"
      class="flex flex-col gap-0.5 p-1 border-r border-n-weak last:border-r-0 min-h-[2rem]"
    >
      <AgendaEventPill
        v-for="event in eventsFor(day)"
        :key="event.id"
        :event="event"
        @click="emit('open-event', event)"
      />
    </div>
  </div>
</template>
