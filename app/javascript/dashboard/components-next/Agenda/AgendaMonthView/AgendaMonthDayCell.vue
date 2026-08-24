<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { MAX_PILLS_PER_CELL } from '../constants';
import AgendaEventPill from '../AgendaTimeGrid/AgendaEventPill.vue';

const props = defineProps({
  date: {
    type: Date,
    required: true,
  },
  isCurrentMonth: {
    type: Boolean,
    default: true,
  },
  isToday: {
    type: Boolean,
    default: false,
  },
  events: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['click-day', 'click-event']);

const visibleEvents = computed(() => props.events.slice(0, MAX_PILLS_PER_CELL));
const overflowCount = computed(() => Math.max(props.events.length - MAX_PILLS_PER_CELL, 0));
const dayNumber = computed(() => format(props.date, 'd'));

const handleCellClick = () => emit('click-day', props.date);
const handleEventClick = event => emit('click-event', event);
</script>

<template>
  <button
    type="button"
    class="flex flex-col items-stretch gap-1 p-1.5 min-h-[6rem] text-left border border-n-weak transition-colors hover:bg-n-alpha-1"
    :class="{ 'bg-n-alpha-1': !isCurrentMonth }"
    @click="handleCellClick"
  >
    <span
      class="self-start grid place-content-center size-6 rounded-full text-xs"
      :class="[
        isToday ? 'bg-n-blue-9 text-white font-medium' : 'text-n-slate-11',
        !isCurrentMonth && !isToday ? 'text-n-slate-9' : '',
      ]"
    >
      {{ dayNumber }}
    </span>

    <div class="flex flex-col gap-0.5 min-w-0">
      <AgendaEventPill
        v-for="event in visibleEvents"
        :key="event.id"
        :event="event"
        @click="handleEventClick(event)"
      />
      <span v-if="overflowCount > 0" class="px-1.5 text-xs text-n-slate-11">
        +{{ overflowCount }}
      </span>
    </div>
  </button>
</template>
