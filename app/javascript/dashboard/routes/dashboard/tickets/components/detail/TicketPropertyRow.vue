<script setup>
defineProps({
  label: { type: String, required: true },
});
</script>

<template>
  <div class="flex flex-col gap-1 min-w-0">
    <span class="text-xs uppercase tracking-wide text-n-slate-10">
      {{ label }}
    </span>
    <slot />
  </div>
</template>
