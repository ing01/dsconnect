<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  date: { type: String, required: true },
  type: { type: String, required: true },
  platform: { type: String, default: 'web' },
  title: { type: String, required: true },
  description: { type: String, required: true },
  comparison: { type: Object, default: null },
});

const icon = computed(() =>
  props.type === 'design' ? 'i-lucide-palette' : 'i-lucide-sparkles'
);

const platformLabel = computed(() =>
  props.platform === 'mobile' ? 'App mobile' : 'Sistema web'
);

const gradientStyle = colors => ({
  background: `linear-gradient(to right, ${colors[0]}, ${colors[1]})`,
});
</script>

<template>
  <div
    class="flex gap-4 p-4 border rounded-2xl border-n-weak bg-n-solid-1"
  >
    <div
      class="grid flex-shrink-0 rounded-xl place-content-center size-10 bg-gradient-to-br from-n-blue-9 to-n-teal-9"
    >
      <Icon :icon="icon" class="text-white size-5" />
    </div>
    <div class="flex-1 min-w-0">
      <div class="flex items-start justify-between gap-2">
        <span class="font-medium text-n-slate-12">{{ title }}</span>
        <span class="flex items-center flex-shrink-0 gap-2">
          <span
            v-if="platform === 'mobile'"
            class="px-2 py-0.5 rounded-full text-[11px] font-medium bg-n-teal-3 text-n-teal-11"
          >
            {{ platformLabel }}
          </span>
          <span class="text-xs text-n-slate-10">{{ date }}</span>
        </span>
      </div>
      <p class="mt-1 text-sm text-n-slate-11">{{ description }}</p>

      <div v-if="comparison" class="flex items-center gap-3 mt-3">
        <template v-if="comparison.kind === 'color'">
          <div class="flex items-center gap-1.5">
            <span
              class="rounded-full size-5"
              :style="{ backgroundColor: comparison.before }"
            />
            <span class="text-xs text-n-slate-10">{{
              $t('PRINCIPAL.BEFORE')
            }}</span>
          </div>
          <Icon icon="i-lucide-arrow-right" class="text-n-slate-9 size-4" />
          <div class="flex items-center gap-1.5">
            <span
              class="rounded-full size-5"
              :style="gradientStyle(comparison.after)"
            />
            <span class="text-xs text-n-slate-10">{{
              $t('PRINCIPAL.AFTER')
            }}</span>
          </div>
        </template>
        <template v-else-if="comparison.kind === 'text'">
          <span
            class="px-2 py-0.5 rounded-full text-xs text-n-slate-10 line-through bg-n-slate-3"
          >
            {{ comparison.before }}
          </span>
          <Icon icon="i-lucide-arrow-right" class="text-n-slate-9 size-4" />
          <span
            class="px-2 py-0.5 rounded-full text-xs text-white bg-gradient-to-r from-n-blue-9 to-n-teal-9"
          >
            {{ comparison.after }}
          </span>
        </template>
      </div>
    </div>
  </div>
</template>
