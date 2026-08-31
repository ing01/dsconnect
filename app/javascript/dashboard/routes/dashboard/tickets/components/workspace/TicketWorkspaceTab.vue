<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  tab: { type: Object, required: true },
  isActive: { type: Boolean, default: false },
});

defineEmits(['select', 'close']);

const { t } = useI18n();

const number = computed(() =>
  props.tab.displayId ? `#${props.tab.displayId}` : '#…'
);

// `#26 - EMPRESA - Titulo`, with each empty part dropped so a Ticket without an
// Empresa does not render a dangling separator.
const label = computed(() =>
  [number.value, props.tab.company?.toUpperCase(), props.tab.title]
    .filter(Boolean)
    .join(' - ')
);

// The label is clipped by design, so the full identification - including the
// Solicitante, which never fits - is only available here.
const tooltip = computed(() =>
  [number.value, props.tab.company, props.tab.requester, props.tab.title]
    .filter(Boolean)
    .join(' | ')
);
</script>

<template>
  <div
    v-tooltip="tooltip"
    class="group flex items-center flex-shrink-0 h-9 gap-1 pl-3 pr-1 border rounded-lg min-w-[160px] max-w-[260px] transition-colors"
    :class="
      isActive
        ? 'border-n-brand bg-n-alpha-2 text-n-slate-12'
        : 'border-n-weak bg-n-alpha-black2 text-n-slate-11 hover:border-n-slate-8'
    "
  >
    <button
      type="button"
      class="flex items-center min-w-0 gap-2 text-sm truncate focus-visible:outline-none"
      :class="isActive ? 'font-medium' : ''"
      :aria-current="isActive ? 'page' : undefined"
      @click="$emit('select', tab.id)"
    >
      <!-- Reserved for the per-tab indicators (update, new message, SLA) that
           are deliberately not part of this change: keeping the slot here means
           adding them later does not re-flow the bar. -->
      <span class="flex items-center flex-shrink-0 empty:hidden">
        <slot name="indicators" />
      </span>
      <span class="truncate">{{ label }}</span>
    </button>

    <button
      type="button"
      class="flex items-center justify-center flex-shrink-0 ml-auto rounded size-7 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-label="t('TICKET.WORKSPACE.CLOSE_TAB')"
      @click.stop="$emit('close', tab.id)"
    >
      <span class="i-lucide-x size-[18px]" />
    </button>
  </div>
</template>
