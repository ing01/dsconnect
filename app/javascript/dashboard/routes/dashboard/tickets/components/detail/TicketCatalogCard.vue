<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const { t } = useI18n();

// Only the Item is stored on the ticket; the two levels above it come from the
// association, so the path is never duplicated as text.
const path = computed(() => props.ticket.service_catalog_item?.full_path || []);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-2 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.CATALOG.TITLE') }}
    </h2>

    <p
      v-if="!path.length"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-tag" class="flex-shrink-0 size-4" />
      {{ t('TICKET.CATALOG.UNCLASSIFIED') }}
    </p>

    <ol v-else class="flex flex-col gap-0.5 min-w-0">
      <li
        v-for="(level, index) in path"
        :key="level"
        class="flex items-center gap-1 min-w-0 text-sm"
        :class="index === 0 ? 'text-n-slate-12' : 'text-n-slate-11'"
        :style="index ? `padding-inline-start: ${index * 0.75}rem` : ''"
      >
        <Icon
          v-if="index"
          icon="i-lucide-corner-down-right"
          class="flex-shrink-0 size-3 text-n-slate-10"
        />
        <span class="truncate" :title="level">{{ level }}</span>
      </li>
    </ol>
  </section>
</template>
