<script setup>
defineProps({
  event: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);

const handleClick = e => {
  e.stopPropagation();
  emit('click');
};
</script>

<template>
  <button
    type="button"
    class="flex items-center gap-1.5 w-full px-1.5 py-0.5 rounded-md text-xs text-left truncate text-white hover:opacity-90 transition-opacity"
    :style="{ backgroundColor: event.color || '#2563eb' }"
    @click="handleClick"
  >
    <span class="truncate">{{ event.title }}</span>
    <span v-if="event.tickets?.length" class="shrink-0 i-lucide-ticket size-3" />
  </button>
</template>
