<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { formatMesaName } from 'dashboard/helper/mesaName';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
  selectedTeamId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const isOpen = ref(false);

const selectedTeam = computed(() =>
  props.teams.find(team => team.id === props.selectedTeamId)
);

const selectedLabel = computed(() =>
  selectedTeam.value
    ? formatMesaName(selectedTeam.value.name)
    : t('TICKET.MESA_SELECTOR.NONE')
);

// DropdownMenu filters `label` locally, so the search box works on the same
// capitalized name the user sees.
const menuItems = computed(() =>
  props.teams.map(team => ({
    label: formatMesaName(team.name),
    value: team.id,
    action: 'selectMesa',
    icon: 'i-lucide-star',
    isSelected: team.id === props.selectedTeamId,
  }))
);

const handleAction = ({ value }) => {
  isOpen.value = false;
  if (value !== props.selectedTeamId) emit('select', value);
};
</script>

<template>
  <OnClickOutside class="relative flex-shrink-0" @trigger="isOpen = false">
    <Button
      variant="solid"
      color="blue"
      size="sm"
      icon="i-lucide-users"
      class="!h-8 max-w-64"
      :aria-label="t('TICKET.MESA_SELECTOR.LABEL')"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="isOpen = !isOpen"
    >
      <span class="truncate" :title="selectedLabel">
        {{ t('TICKET.MESA_SELECTOR.PREFIX', { name: selectedLabel }) }}
      </span>
      <Icon
        :icon="isOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        class="shrink-0"
      />
    </Button>

    <!-- `max-h-80` bounds the panel while the search box stays pinned: only the
         item list inside DropdownMenu scrolls. -->
    <DropdownMenu
      v-if="isOpen"
      :menu-items="menuItems"
      show-search
      :search-placeholder="t('TICKET.MESA_SELECTOR.SEARCH')"
      empty-state-message="TICKET.MESA_SELECTOR.EMPTY"
      class="mt-1 top-full ltr:left-0 rtl:right-0 w-64 max-w-[calc(100vw-2rem)] max-h-80"
      @action="handleAction"
    >
      <template #label="{ item }">
        <span
          class="flex-1 min-w-0 text-sm font-420 truncate ltr:text-left rtl:text-right"
          :title="item.label"
        >
          {{ item.label }}
        </span>
      </template>
      <template #trailing-icon="{ item }">
        <Icon
          v-if="item.isSelected"
          icon="i-lucide-check"
          class="shrink-0 size-4 text-n-brand"
        />
      </template>
    </DropdownMenu>
  </OnClickOutside>
</template>
