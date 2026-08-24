<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  sort: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const isOpen = ref(false);

const hasSort = computed(() => Boolean(props.sort?.field));

// Spelled out rather than derived from TICKET_SORT_FIELDS so every i18n key is
// a literal the linter can verify; this list also sets the order of the rows.
const fields = computed(() => [
  { value: 'title', label: t('TICKET.SORT.FIELDS.TITLE') },
  { value: 'display_id', label: t('TICKET.SORT.FIELDS.DISPLAY_ID') },
  { value: 'assignee_name', label: t('TICKET.SORT.FIELDS.ASSIGNEE_NAME') },
  { value: 'company_name', label: t('TICKET.SORT.FIELDS.COMPANY_NAME') },
  { value: 'priority', label: t('TICKET.SORT.FIELDS.PRIORITY') },
  { value: 'created_at', label: t('TICKET.SORT.FIELDS.CREATED_AT') },
  { value: 'status', label: t('TICKET.SORT.FIELDS.STATUS') },
]);

const isActive = (field, direction) =>
  props.sort?.field === field && props.sort?.direction === direction;

// One sort at a time: picking a direction replaces whatever was active, and
// clicking the active one again drops back to the board's own order.
const apply = (field, direction) => {
  emit('update', isActive(field, direction) ? null : { field, direction });
  isOpen.value = false;
};

const clear = () => {
  emit('update', null);
  isOpen.value = false;
};

const directionButtonClass = (field, direction) => [
  'flex flex-shrink-0 items-center justify-center size-7 rounded-md transition-colors',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand',
  isActive(field, direction)
    ? 'bg-n-brand/15 text-n-brand'
    : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2',
];
</script>

<template>
  <OnClickOutside class="relative flex-shrink-0" @trigger="isOpen = false">
    <Button
      v-tooltip="t('TICKET.SORT.BUTTON')"
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-arrow-up-down"
      class="!h-8"
      :class="hasSort ? '!text-n-brand' : ''"
      :aria-label="t('TICKET.SORT.BUTTON')"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="isOpen = !isOpen"
    />

    <div
      v-if="isOpen"
      class="absolute z-50 mt-1 top-full ltr:right-0 rtl:left-0 w-64 max-w-[calc(100vw-2rem)] flex flex-col rounded-xl shadow-lg bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container"
    >
      <p
        class="px-3 pt-3 pb-2 mb-0 text-xs font-medium tracking-wide uppercase text-n-slate-11"
      >
        {{ t('TICKET.SORT.TITLE') }}
      </p>

      <button
        type="button"
        class="mx-2 px-2 py-1.5 rounded-lg text-sm text-start transition-colors disabled:opacity-50 disabled:cursor-not-allowed enabled:text-n-slate-12 enabled:hover:bg-n-alpha-2 text-n-slate-11 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :disabled="!hasSort"
        @click="clear"
      >
        {{ t('TICKET.SORT.CLEAR') }}
      </button>

      <div class="h-px mx-2 my-2 bg-n-alpha-2" />

      <ul
        class="flex flex-col gap-0.5 px-2 pb-2 mb-0 overflow-y-auto max-h-[60vh]"
      >
        <li
          v-for="field in fields"
          :key="field.value"
          class="flex items-center justify-between gap-2 ps-2 pe-1 py-0.5 rounded-lg"
        >
          <span
            class="min-w-0 text-sm truncate text-n-slate-12"
            :title="field.label"
          >
            {{ field.label }}
          </span>
          <div class="flex items-center gap-0.5 flex-shrink-0">
            <button
              v-tooltip="t('TICKET.SORT.ASC')"
              type="button"
              :class="directionButtonClass(field.value, 'asc')"
              :aria-label="t('TICKET.SORT.ASC_BY', { field: field.label })"
              :aria-pressed="isActive(field.value, 'asc')"
              @click="apply(field.value, 'asc')"
            >
              <Icon icon="i-lucide-arrow-up" class="size-4" />
            </button>
            <button
              v-tooltip="t('TICKET.SORT.DESC')"
              type="button"
              :class="directionButtonClass(field.value, 'desc')"
              :aria-label="t('TICKET.SORT.DESC_BY', { field: field.label })"
              :aria-pressed="isActive(field.value, 'desc')"
              @click="apply(field.value, 'desc')"
            >
              <Icon icon="i-lucide-arrow-down" class="size-4" />
            </button>
          </div>
        </li>
      </ul>
    </div>
  </OnClickOutside>
</template>
