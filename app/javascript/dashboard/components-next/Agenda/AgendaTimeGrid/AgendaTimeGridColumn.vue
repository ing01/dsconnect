<script setup>
import { computed } from 'vue';
import { eventToPosition, computeOverlapLayout, slotClickToDate } from '../helpers/agendaLayoutHelper';
import AgendaEventBlock from './AgendaEventBlock.vue';

const props = defineProps({
  day: {
    type: Date,
    required: true,
  },
  events: {
    type: Array,
    default: () => [],
  },
  hourHeight: {
    type: Number,
    required: true,
  },
  dayStartHour: {
    type: Number,
    required: true,
  },
  dayEndHour: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['slot-click', 'event-click']);

const hourCount = computed(() => props.dayEndHour - props.dayStartHour);

const positionedEvents = computed(() => {
  const positioned = props.events.map(event =>
    eventToPosition(event, props.day, {
      hourHeight: props.hourHeight,
      dayStartHour: props.dayStartHour,
      dayEndHour: props.dayEndHour,
    })
  );
  return computeOverlapLayout(positioned);
});

const handleBackgroundClick = e => {
  const rect = e.currentTarget.getBoundingClientRect();
  const offsetY = e.clientY - rect.top;
  const clickedAt = slotClickToDate(props.day, offsetY, {
    hourHeight: props.hourHeight,
    dayStartHour: props.dayStartHour,
  });
  emit('slot-click', clickedAt);
};
</script>

<template>
  <div
    class="relative flex-1 min-w-0 border-r border-n-weak last:border-r-0"
    :style="{ height: `${hourCount * hourHeight}px` }"
    @click="handleBackgroundClick"
  >
    <div
      v-for="hour in hourCount"
      :key="hour"
      class="border-b border-n-weak transition-colors cursor-pointer hover:bg-n-slate-2 dark:hover:bg-n-solid-2"
      :style="{ height: `${hourHeight}px` }"
    />

    <AgendaEventBlock
      v-for="item in positionedEvents"
      :key="item.event.id"
      :event="item.event"
      :top="item.top"
      :height="item.height"
      :left="item.left"
      :width="item.width"
      :clipped-at-start="item.clippedAtStart"
      :clipped-at-end="item.clippedAtEnd"
      @click="emit('event-click', item.event)"
    />
  </div>
</template>
