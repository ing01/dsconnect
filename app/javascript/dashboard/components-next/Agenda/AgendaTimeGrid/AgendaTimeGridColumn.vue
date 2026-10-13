<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { isToday as isDateToday } from 'date-fns';
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

const emit = defineEmits(['slot-click', 'event-click', 'event-drag-end']);

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

// Linha de "agora" - so' aparece na coluna de hoje, e so' dentro da janela
// visivel (8h-18h) - atualiza sozinha a cada minuto, sem precisar de F5.
const now = ref(new Date());
let nowTimer = null;
onMounted(() => {
  nowTimer = setInterval(() => {
    now.value = new Date();
  }, 60_000);
});
onUnmounted(() => clearInterval(nowTimer));

const isTodayColumn = computed(() => isDateToday(props.day));
const nowTopPx = computed(() => {
  const minutesFromDayStart = (now.value.getHours() - props.dayStartHour) * 60 + now.value.getMinutes();
  return (minutesFromDayStart / 60) * props.hourHeight;
});
const showNowLine = computed(
  () => isTodayColumn.value && nowTopPx.value >= 0 && nowTopPx.value <= hourCount.value * props.hourHeight
);
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
      :draggable="!item.event.is_recurring"
      @click="emit('event-click', item.event)"
      @drag-end="({ startAt, endAt }) => emit('event-drag-end', { event: item.event, startAt, endAt })"
    />

    <div
      v-if="showNowLine"
      class="absolute inset-x-0 z-10 flex items-center pointer-events-none"
      :style="{ top: `${nowTopPx}px` }"
    >
      <span class="-ml-1 size-2 rounded-full bg-n-ruby-9" />
      <span class="flex-1 h-px bg-n-ruby-9" />
    </div>
  </div>
</template>
