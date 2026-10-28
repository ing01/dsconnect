<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
  // Extending a deadline is gated more tightly than ordinary ticket handling
  // (TicketPolicy#add_sla_hours? is admin or assignee), so the menu is told
  // separately rather than inferring it from `canUpdate`.
  canAddSlaHours: { type: Boolean, default: false },
  currentUserId: { type: [Number, String], default: null },
});

const emit = defineEmits(['action']);

const { t } = useI18n();

const isOpen = ref(false);

const isTerminal = computed(() =>
  ['closed', 'cancelled'].includes(props.ticket.status)
);

// Already the owner: taking the ticket again would be a no-op, so the entry is
// disabled rather than silently doing nothing.
const isAssignedToMe = computed(
  () =>
    props.currentUserId != null &&
    String(props.ticket.assignee_id) === String(props.currentUserId)
);

const label = key => t(`TICKET.ACTIONS.${key}`);

const relationshipItems = computed(() => [
  {
    label: label('CREATE_CHILD'),
    value: 'createChild',
    action: 'createChild',
    icon: 'i-lucide-git-branch-plus',
    disabled: isTerminal.value,
  },
  {
    label: props.ticket.parent
      ? label('CHANGE_PARENT')
      : label('REFERENCE_PARENT'),
    value: 'setParent',
    action: 'setParent',
    icon: 'i-lucide-corner-left-up',
    disabled: !props.canUpdate,
  },
  {
    label: label('MERGE'),
    value: 'merge',
    action: 'merge',
    icon: 'i-lucide-combine',
    // A ticket that was itself merged into another is no longer the survivor of
    // anything, and a terminal ticket cannot absorb new ones.
    disabled:
      !props.canUpdate || isTerminal.value || !!props.ticket.merged_into,
  },
  {
    label: label('DUPLICATE'),
    value: 'duplicate',
    action: 'duplicate',
    icon: 'i-lucide-copy',
  },
]);

const operationItems = computed(() => {
  const items = [];

  // Hidden entirely when the ticket is already mine - the reference app leaves
  // a dead entry there, which reads as a bug.
  if (!isAssignedToMe.value) {
    items.push({
      label: label('ASSIGN_TO_ME'),
      value: 'assignToMe',
      action: 'assignToMe',
      icon: 'i-lucide-user-check',
      disabled: !props.canUpdate || isTerminal.value,
    });
  }

  items.push(
    {
      label: label('TRANSFER'),
      value: 'transfer',
      action: 'transfer',
      icon: 'i-lucide-arrow-right-left',
      disabled: !props.canUpdate,
    },
    // Impedir e liberar aparecem um de cada vez, conforme o estado atual: os
    // dois juntos obrigariam a pessoa a saber em qual deles o ticket esta.
    props.ticket.blocked
      ? {
          label: label('UNBLOCK'),
          value: 'unblock',
          icon: 'i-lucide-play',
          disabled: !props.canUpdate,
        }
      : {
          label: label('BLOCK'),
          value: 'block',
          icon: 'i-lucide-octagon-pause',
          disabled: !props.canUpdate || isTerminal.value,
        },
    {
      label: label('RELATED_CONVERSATIONS'),
      value: 'relatedConversations',
      action: 'relatedConversations',
      icon: 'i-lucide-messages-square',
    }
  );

  return items;
});

// The whole section disappears without the permission, rather than showing a
// permanently disabled row.
const slaItems = computed(() =>
  props.canAddSlaHours
    ? [
        {
          label: label('ADD_SLA_HOURS'),
          value: 'addSlaHours',
          action: 'addSlaHours',
          icon: 'i-lucide-clock-plus',
        },
      ]
    : []
);

// `action: 'delete'` is what DropdownMenu paints in `text-n-ruby-11`, which is
// how the destructive block reads as destructive.
const closingItems = computed(() => {
  const items = [];

  if (props.ticket.status !== 'closed') {
    items.push({
      label: label('CLOSE'),
      value: 'close',
      action: 'delete',
      icon: 'i-lucide-circle-x',
      disabled: !props.canUpdate,
    });
  }
  // Replaces the closing pair once the ticket is no longer open.
  if (props.ticket.status !== 'open') {
    items.push({
      label: label('REOPEN'),
      value: 'reopen',
      action: 'reopen',
      icon: 'i-lucide-rotate-ccw',
      disabled: !props.canUpdate,
    });
  }

  return items;
});

// Section titles are omitted on purpose: DropdownMenu already draws a divider
// between sections, and four headings for ten entries makes the menu heavier
// than the grouping is worth.
const menuSections = computed(() =>
  [
    { items: relationshipItems.value },
    { items: operationItems.value },
    { items: slaItems.value },
    { items: closingItems.value },
  ].filter(section => section.items.length > 0)
);

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
      :menu-sections="menuSections"
      class="mt-1 top-full ltr:right-0 rtl:left-0 w-60 max-w-[calc(100vw-2rem)] max-h-[70vh]"
      @action="handleAction"
    />
  </OnClickOutside>
</template>
