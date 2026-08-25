<script>
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { statusColor, priorityColor } from '../helpers/ticketLabels';

export default {
  components: {
    WootLabel,
    Icon,
    NextButton,
    DropdownMenu,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    agents: {
      type: Array,
      default: () => [],
    },
  },
  // The menu emits by computed name (see the menu handler below), so the
  // linter cannot see these being fired - they are declared and very much
  // used. Renaming them would break the board's listeners.
  // eslint-disable-next-line vue/no-unused-emit-declarations
  emits: ['click', 'edit', 'open-conversation', 'resolve', 'reopen', 'close'],
  data() {
    return {
      showMenu: false,
    };
  },
  computed: {
    priorityColor() {
      return priorityColor(this.ticket.priority);
    },
    priorityLabel() {
      return this.ticket.priority
        ? this.$t(`TICKET.FORM.PRIORITY.${this.ticket.priority.toUpperCase()}`)
        : '';
    },
    statusColor() {
      return statusColor(this.ticket.status);
    },
    statusLabel() {
      return this.ticket.status
        ? this.$t(`TICKET.STATUS.${this.ticket.status.toUpperCase()}`)
        : '';
    },
    assigneeName() {
      const agent = this.agents.find(a => a.id === this.ticket.assignee_id);
      return agent?.name || '';
    },
    conversationCount() {
      return this.ticket.conversation_ids?.length || 0;
    },
    menuItems() {
      const items = [
        {
          label: this.$t('TICKET.CARD.MENU.OPEN'),
          action: 'open',
          value: 'open',
          icon: 'i-lucide-square-arrow-out-up-right',
        },
        {
          label: this.$t('TICKET.CARD.MENU.EDIT'),
          action: 'edit',
          value: 'edit',
          icon: 'i-lucide-pencil',
        },
      ];

      if (this.conversationCount) {
        items.push({
          label: this.$t('TICKET.CARD.MENU.OPEN_CONVERSATION'),
          action: 'open-conversation',
          value: 'open-conversation',
          icon: 'i-lucide-message-circle',
        });
      }

      if (this.ticket.status === 'open') {
        items.push({
          label: this.$t('TICKET.CARD.MENU.RESOLVE'),
          action: 'resolve',
          value: 'resolve',
          icon: 'i-lucide-check',
        });
      } else if (this.ticket.status === 'resolved') {
        items.push(
          {
            label: this.$t('TICKET.CARD.MENU.CLOSE'),
            action: 'close',
            value: 'close',
            icon: 'i-lucide-check-check',
          },
          {
            label: this.$t('TICKET.CARD.MENU.REOPEN'),
            action: 'reopen',
            value: 'reopen',
            icon: 'i-lucide-rotate-ccw',
          }
        );
      } else if (this.ticket.status === 'closed') {
        items.push({
          label: this.$t('TICKET.CARD.MENU.REOPEN'),
          action: 'reopen',
          value: 'reopen',
          icon: 'i-lucide-rotate-ccw',
        });
      }

      return items;
    },
  },
  methods: {
    toggleMenu() {
      this.showMenu = !this.showMenu;
    },
    closeMenu() {
      this.showMenu = false;
    },
    onMenuAction({ action }) {
      this.closeMenu();
      this.$emit(action === 'open' ? 'click' : action, this.ticket);
    },
  },
};
</script>

<template>
  <div
    class="drag-handle group relative flex flex-col gap-2 rounded-xl border border-n-weak bg-n-solid-1 p-3 cursor-pointer hover:border-n-slate-6 hover:shadow-sm transition-shadow"
    @click="$emit('click', ticket)"
  >
    <div class="flex items-start justify-between gap-2">
      <p class="text-sm font-medium text-n-slate-12 line-clamp-2">
        <span v-if="ticket.display_id" class="text-n-slate-10 font-normal">
          #{{ ticket.display_id }}
        </span>
        {{ ticket.title }}
      </p>
      <div v-on-clickaway="closeMenu" class="relative flex-shrink-0">
        <NextButton
          icon="i-lucide-ellipsis-vertical"
          color="slate"
          variant="ghost"
          size="xs"
          class="opacity-0 group-hover:opacity-100"
          :class="showMenu ? 'opacity-100' : ''"
          @click.stop="toggleMenu"
        />
        <DropdownMenu
          v-if="showMenu"
          :menu-items="menuItems"
          class="ltr:right-0 rtl:left-0 mt-1 w-48 top-full"
          @click.stop
          @action="onMenuAction"
        />
      </div>
    </div>

    <p
      v-if="ticket.company_name"
      class="text-xs text-n-slate-11 truncate"
      :title="ticket.company_name"
    >
      {{ ticket.company_name }}
    </p>

    <div class="flex items-center flex-wrap gap-1.5">
      <WootLabel
        v-if="ticket.status"
        :label="statusLabel"
        :color="statusColor"
        compact
      />
      <WootLabel
        v-if="ticket.priority"
        :label="priorityLabel"
        :color="priorityColor"
        compact
      />
      <span v-if="!ticket.priority" class="text-xs text-n-slate-10">
        {{ $t('TICKET.FORM.PRIORITY.NONE') }}
      </span>
    </div>

    <div class="flex items-center justify-between gap-2">
      <div v-if="assigneeName" class="flex items-center gap-1.5 min-w-0">
        <span
          class="flex size-5 flex-shrink-0 items-center justify-center rounded-full bg-n-slate-4 text-[10px] font-medium text-n-slate-12"
        >
          {{ assigneeName.charAt(0).toUpperCase() }}
        </span>
        <span class="text-xs text-n-slate-11 truncate">{{ assigneeName }}</span>
      </div>
      <div v-else />

      <div
        v-if="conversationCount"
        class="flex items-center gap-1 text-xs text-n-slate-11 flex-shrink-0"
      >
        <Icon icon="i-lucide-message-circle" class="size-3.5" />
        {{ conversationCount }}
      </div>
    </div>
  </div>
</template>
