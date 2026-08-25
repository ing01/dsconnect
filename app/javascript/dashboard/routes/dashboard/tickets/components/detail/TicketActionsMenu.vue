<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
});

const emit = defineEmits(['action']);

const { t } = useI18n();

const isOpen = ref(false);

const hasConversation = computed(
  () => (props.ticket.conversations || []).length > 0
);

// Only actions that are actually wired. Lifecycle entries follow the model's
// own transitions, so "Fechar" never shows on an already closed ticket.
const menuItems = computed(() => {
  const items = [
    {
      label: t('TICKET.DETAIL.ACTIONS.EDIT'),
      value: 'edit',
      action: 'edit',
      icon: 'i-lucide-pencil',
      disabled: !props.canUpdate,
    },
    {
      label: t('TICKET.DETAIL.ACTIONS.OPEN_CONVERSATION'),
      value: 'openConversation',
      action: 'openConversation',
      icon: 'i-lucide-messages-square',
      disabled: !hasConversation.value,
    },
  ];

  if (props.ticket.status !== 'resolved') {
    items.push({
      label: t('TICKET.DETAIL.ACTIONS.RESOLVE'),
      value: 'resolve',
      action: 'resolve',
      icon: 'i-lucide-circle-check',
      disabled: !props.canUpdate,
    });
  }
  if (props.ticket.status !== 'closed') {
    items.push({
      label: t('TICKET.DETAIL.ACTIONS.CLOSE'),
      value: 'close',
      action: 'close',
      icon: 'i-lucide-circle-x',
      disabled: !props.canUpdate,
    });
  }
  if (props.ticket.status !== 'open') {
    items.push({
      label: t('TICKET.DETAIL.ACTIONS.REOPEN'),
      value: 'reopen',
      action: 'reopen',
      icon: 'i-lucide-rotate-ccw',
      disabled: !props.canUpdate,
    });
  }

  items.push({
    label: t('TICKET.DETAIL.ACTIONS.COPY_LINK'),
    value: 'copyLink',
    action: 'copyLink',
    icon: 'i-lucide-link',
  });

  return items;
});

const handleAction = ({ value }) => {
  isOpen.value = false;
  emit('action', value);
};
</script>

<template>
  <OnClickOutside class="relative flex-shrink-0" @trigger="isOpen = false">
    <Button
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-chevron-down"
      trailing-icon
      class="!h-8"
      :label="t('TICKET.DETAIL.ACTIONS.LABEL')"
      :aria-label="t('TICKET.DETAIL.ACTIONS.LABEL')"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="isOpen = !isOpen"
    />
    <DropdownMenu
      v-if="isOpen"
      :menu-items="menuItems"
      class="mt-1 top-full ltr:right-0 rtl:left-0 w-56 max-w-[calc(100vw-2rem)]"
      @action="handleAction"
    />
  </OnClickOutside>
</template>
