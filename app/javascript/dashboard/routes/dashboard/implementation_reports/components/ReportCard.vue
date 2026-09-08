<script setup>
import Spinner from 'shared/components/Spinner.vue';

defineProps({
  header: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div
    class="flex flex-col p-4 rounded-xl flex-grow text-n-slate-12 shadow outline-1 outline outline-n-container bg-n-solid-2 min-h-[8rem]"
  >
    <div v-if="header" class="mb-3">
      <h5 class="mb-0 text-n-slate-12 font-medium text-sm">{{ header }}</h5>
    </div>
    <div v-if="isLoading" class="flex-1 flex items-center justify-center py-6">
      <Spinner />
    </div>
    <div v-else class="flex-1 min-w-0">
      <slot />
    </div>
  </div>
</template>
