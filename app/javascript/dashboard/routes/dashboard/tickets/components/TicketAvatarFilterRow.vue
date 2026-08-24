<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { onClickOutside } from '@vueuse/core';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  agents: {
    type: Array,
    default: () => [],
  },
  selectedAgentIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['select']);

// Keeps the header on one line at common desktop widths; everyone beyond this
// is reachable through the "+N" menu instead of stretching the row.
const MAX_VISIBLE_AGENTS = 6;

const { t } = useI18n();

const isMenuOpen = ref(false);
const menuContainer = ref(null);

onClickOutside(menuContainer, () => {
  isMenuOpen.value = false;
});

const hasFilter = computed(() => props.selectedAgentIds.length > 0);

const isSelected = agentId => props.selectedAgentIds.includes(agentId);

// Every selected agent stays on the row - they are the active filter, so hiding
// one behind "+N" would leave no way to tell who the board is filtered by. The
// remaining slots are filled with unselected members, in order.
const visibleAgents = computed(() => {
  const selected = props.agents.filter(agent => isSelected(agent.id));
  const rest = props.agents.filter(agent => !isSelected(agent.id));
  const freeSlots = Math.max(MAX_VISIBLE_AGENTS - selected.length, 0);

  return [...selected, ...rest.slice(0, freeSlots)];
});

const overflowAgents = computed(() =>
  props.agents.filter(agent => !visibleAgents.value.includes(agent))
);

const overflowLabel = computed(() => `+${overflowAgents.value.length}`);

const overflowMenuItems = computed(() =>
  overflowAgents.value.map(agent => ({
    label: agent.name,
    value: agent.id,
    action: 'filterByAgent',
    thumbnail: { name: agent.name, src: agent.thumbnail },
    isSelected: isSelected(agent.id),
  }))
);

// Adds the agent to the filter, or drops just that one when already selected.
const toggleAgent = agentId => {
  emit(
    'select',
    isSelected(agentId)
      ? props.selectedAgentIds.filter(id => id !== agentId)
      : [...props.selectedAgentIds, agentId]
  );
};

// The menu stays open so several agents can be picked in one go.
const handleMenuAction = ({ value }) => toggleAgent(value);
</script>

<template>
  <div class="flex items-center gap-1.5 min-w-0 flex-wrap">
    <button
      type="button"
      class="flex items-center h-7 px-2.5 rounded-full text-xs font-medium border transition-colors flex-shrink-0"
      :class="
        hasFilter
          ? 'border-n-weak text-n-slate-11 hover:bg-n-slate-3'
          : 'bg-n-brand/10 border-n-brand text-n-blue-11'
      "
      :aria-pressed="!hasFilter"
      @click="emit('select', [])"
    >
      {{ t('TICKET.FILTERS.ALL_AGENTS') }}
    </button>

    <button
      v-for="agent in visibleAgents"
      :key="agent.id"
      v-tooltip="agent.name"
      type="button"
      class="flex-shrink-0 rounded-full transition-shadow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="
        isSelected(agent.id)
          ? 'ring-2 ring-n-brand ring-offset-2 ring-offset-n-background'
          : 'opacity-60 hover:opacity-100'
      "
      :aria-label="agent.name"
      :aria-pressed="isSelected(agent.id)"
      @click="toggleAgent(agent.id)"
    >
      <Avatar
        :name="agent.name"
        :src="agent.thumbnail"
        :size="28"
        rounded-full
        hide-offline-status
      />
    </button>

    <div v-if="overflowAgents.length" ref="menuContainer" class="relative">
      <button
        type="button"
        class="flex items-center h-7 px-2.5 rounded-full text-xs font-medium border border-n-weak text-n-slate-11 hover:bg-n-slate-3 transition-colors flex-shrink-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="
          t('TICKET.FILTERS.MORE_AGENTS', { count: overflowAgents.length })
        "
        :aria-expanded="isMenuOpen"
        aria-haspopup="menu"
        @click="isMenuOpen = !isMenuOpen"
      >
        {{ overflowLabel }}
      </button>
      <DropdownMenu
        v-if="isMenuOpen"
        :menu-items="overflowMenuItems"
        show-search
        :search-placeholder="t('TICKET.FILTERS.SEARCH_AGENT')"
        class="top-full mt-2 ltr:left-0 rtl:right-0 max-h-72"
        @action="handleMenuAction"
      />
    </div>

    <button
      v-if="hasFilter"
      type="button"
      class="flex items-center h-7 px-2.5 rounded-full text-xs font-medium border border-n-weak text-n-slate-11 hover:bg-n-slate-3 transition-colors flex-shrink-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      @click="emit('select', [])"
    >
      {{ t('TICKET.FILTERS.CLEAR') }}
    </button>

    <span
      v-if="!agents.length"
      class="text-xs text-n-slate-10 min-w-0 truncate"
    >
      {{ t('TICKET.FILTERS.NO_MESA_MEMBERS') }}
    </span>
  </div>
</template>
