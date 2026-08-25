<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  // Followers watch a ticket in a Mesa, so the candidates are that Mesa's
  // members - the same list the Responsavel comes from.
  members: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const isOpen = ref(false);

const selected = computed(() =>
  props.members.filter(member => props.modelValue.includes(member.id))
);

const options = computed(() =>
  props.members.map(member => ({
    label: member.name,
    value: member.id,
    action: 'toggle',
    isSelected: props.modelValue.includes(member.id),
    thumbnail: { name: member.name, src: member.thumbnail },
  }))
);

// Multi-select: clicking an entry toggles it and the menu stays open, so
// several people can be added in one go.
const toggle = ({ value }) => {
  const next = props.modelValue.includes(value)
    ? props.modelValue.filter(id => id !== value)
    : [...props.modelValue, value];
  emit('update:modelValue', next);
};

const label = computed(() => {
  if (!selected.value.length) return t('TICKET.CREATE.FOLLOWERS.PLACEHOLDER');
  return selected.value.map(member => member.name).join(', ');
});
</script>

<template>
  <OnClickOutside class="relative w-full min-w-0" @trigger="isOpen = false">
    <button
      type="button"
      :disabled="disabled || !members.length"
      class="flex items-center justify-between w-full h-10 gap-2 px-3 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 disabled:opacity-50 disabled:cursor-not-allowed"
      :class="{ 'text-n-slate-10': !selected.length }"
      @click="isOpen = !isOpen"
    >
      <span class="truncate min-w-0 text-left">{{ label }}</span>
      <Icon icon="i-lucide-chevron-down" class="flex-shrink-0 size-4" />
    </button>

    <DropdownMenu
      v-if="isOpen"
      show-search
      :menu-items="options"
      :search-placeholder="t('TICKET.CREATE.FOLLOWERS.SEARCH')"
      empty-state-message="TICKET.CREATE.FOLLOWERS.EMPTY"
      class="mt-1 top-full w-full max-h-64"
      @action="toggle"
    />
  </OnClickOutside>
</template>
