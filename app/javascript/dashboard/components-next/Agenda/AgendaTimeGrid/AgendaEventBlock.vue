<script setup>
import { computed } from 'vue';
import { format, parseISO } from 'date-fns';
import { colorForEvent } from '../helpers/agentColorHelper';

const props = defineProps({
  event: {
    type: Object,
    required: true,
  },
  top: {
    type: Number,
    required: true,
  },
  height: {
    type: Number,
    required: true,
  },
  left: {
    type: Number,
    default: 0,
  },
  width: {
    type: Number,
    default: 100,
  },
  clippedAtStart: {
    type: Boolean,
    default: false,
  },
  clippedAtEnd: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['click']);

const color = computed(() => colorForEvent(props.event));

const handleClick = e => {
  e.stopPropagation();
  emit('click');
};

const timeRangeLabel = () =>
  `${format(parseISO(props.event.start_at), 'HH:mm')} - ${format(parseISO(props.event.end_at), 'HH:mm')}`;
</script>

<template>
  <button
    type="button"
    class="absolute overflow-hidden rounded-md px-2 py-1 text-left text-white shadow-sm hover:opacity-90 transition-opacity"
    :class="{ 'rounded-t-none': clippedAtStart, 'rounded-b-none': clippedAtEnd }"
    :style="{
      top: `${top}px`,
      height: `${height}px`,
      left: `${left}%`,
      width: `calc(${width}% - 4px)`,
      backgroundColor: color,
    }"
    @click="handleClick"
  >
    <span class="block text-xs font-medium truncate">{{ event.title }}</span>
    <span class="block text-[0.6875rem] opacity-90 truncate">{{ timeRangeLabel() }}</span>
  </button>
</template>
