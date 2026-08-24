<script setup>
import { format, parseISO } from 'date-fns';

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
      backgroundColor: event.color || '#2563eb',
    }"
    @click="handleClick"
  >
    <span class="block text-xs font-medium truncate">{{ event.title }}</span>
    <span class="block text-[0.6875rem] opacity-90 truncate">{{ timeRangeLabel() }}</span>
  </button>
</template>
