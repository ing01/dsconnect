<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  icon: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  to: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <router-link
    :to="to"
    class="flex flex-col flex-1 p-4 m-px outline outline-n-container outline-1 bg-n-card rounded-xl hover:outline-n-brand transition-colors"
  >
    <div class="flex items-start justify-between mb-2">
      <div
        class="flex items-center justify-center size-10 rounded-lg bg-n-alpha-2 text-n-slate-11"
      >
        <Icon :icon="icon" class="size-5" />
      </div>
    </div>
    <div class="flex flex-col flex-1">
      <span class="text-heading-3 text-n-slate-12 font-medium mb-1">
        {{ title }}
      </span>
      <p class="text-n-slate-11 text-body-main flex-1">
        {{ description }}
      </p>
      <div class="mt-3">
        <Button :label="$t('REPORT.HUB.OPEN')" icon="i-lucide-arrow-right" link xs />
      </div>
    </div>
  </router-link>
</template>
