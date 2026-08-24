<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { colorForAgent } from '../helpers/agentColorHelper';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
  selectedTeamId: {
    type: [Number, String],
    default: '',
  },
  referenceDate: {
    type: Date,
    required: true,
  },
  view: {
    type: String,
    required: true,
  },
  agents: {
    type: Array,
    default: () => [],
  },
  selectedAgentIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'select-team',
  'change-view',
  'navigate-previous',
  'navigate-next',
  'navigate-today',
  'create-event',
  'toggle-agent',
  'clear-agent-filter',
]);

const { t } = useI18n();

const isAgentFilterOpen = ref(false);
const toggleAgentFilter = () => {
  isAgentFilterOpen.value = !isAgentFilterOpen.value;
};
const closeAgentFilter = () => {
  isAgentFilterOpen.value = false;
};
const agentFilterLabel = computed(() =>
  props.selectedAgentIds.length
    ? t('AGENDA.AGENT_FILTER.BUTTON_WITH_COUNT', props.selectedAgentIds.length)
    : t('AGENDA.AGENT_FILTER.BUTTON')
);

const teamOptions = computed(() =>
  props.teams.map(team => ({ value: team.id, label: team.name }))
);

const viewTabs = computed(() => [
  { label: t('AGENDA.VIEWS.DAY'), value: 'day' },
  { label: t('AGENDA.VIEWS.WEEK'), value: 'week' },
  { label: t('AGENDA.VIEWS.MONTH'), value: 'month' },
]);

const activeViewIndex = computed(() =>
  viewTabs.value.findIndex(tab => tab.value === props.view)
);

const headerLabel = computed(() => {
  if (props.view === 'month') return format(props.referenceDate, 'MMMM yyyy');
  if (props.view === 'day') return format(props.referenceDate, 'PPP');
  return format(props.referenceDate, 'MMMM yyyy');
});

const handleTeamChange = value => emit('select-team', Number(value));
const handleTabChanged = tab => emit('change-view', tab.value);
</script>

<template>
  <div class="flex items-center justify-between gap-4 flex-wrap flex-shrink-0">
    <div class="flex items-center gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12 min-w-[10rem]">
        {{ headerLabel }}
      </h1>
      <div class="flex items-center gap-1">
        <Button icon="i-lucide-chevron-left" variant="ghost" color="slate" size="sm" @click="emit('navigate-previous')" />
        <Button :label="t('AGENDA.TODAY')" variant="ghost" color="slate" size="sm" @click="emit('navigate-today')" />
        <Button icon="i-lucide-chevron-right" variant="ghost" color="slate" size="sm" @click="emit('navigate-next')" />
      </div>
    </div>

    <div class="flex items-center gap-3 flex-wrap">
      <Select
        v-if="teamOptions.length"
        :model-value="selectedTeamId"
        :options="teamOptions"
        :aria-label="t('AGENDA.TEAM_SELECT')"
        @update:model-value="handleTeamChange"
      />

      <OnClickOutside v-if="agents.length" @trigger="closeAgentFilter">
        <div class="relative">
          <Button
            icon="i-lucide-users"
            trailing-icon
            variant="faded"
            :color="selectedAgentIds.length ? 'blue' : 'slate'"
            size="sm"
            :label="agentFilterLabel"
            @click="toggleAgentFilter"
          />
          <div
            v-if="isAgentFilterOpen"
            class="absolute right-0 z-20 mt-1 w-64 p-2 rounded-xl border border-n-weak bg-n-solid-2 shadow-lg"
          >
            <div class="flex items-center justify-between px-1 pb-1.5">
              <span class="text-xs font-medium text-n-slate-11">{{ t('AGENDA.AGENT_FILTER.TITLE') }}</span>
              <button
                v-if="selectedAgentIds.length"
                type="button"
                class="text-xs text-n-blue-11 hover:underline"
                @click="emit('clear-agent-filter')"
              >
                {{ t('AGENDA.AGENT_FILTER.CLEAR') }}
              </button>
            </div>
            <div class="flex flex-col max-h-64 overflow-y-auto">
              <label
                v-for="agent in agents"
                :key="agent.id"
                class="flex items-center gap-2 px-1.5 py-1.5 rounded-lg cursor-pointer hover:bg-n-alpha-1"
              >
                <input
                  type="checkbox"
                  class="rounded"
                  :checked="selectedAgentIds.includes(agent.id)"
                  @change="emit('toggle-agent', agent.id)"
                />
                <span class="shrink-0 size-2 rounded-full" :style="{ backgroundColor: colorForAgent(agent.id) }" />
                <Avatar :name="agent.name" :src="agent.thumbnail || agent.avatar_url" :size="20" rounded-full />
                <span class="text-sm text-n-slate-12 truncate">{{ agent.name }}</span>
              </label>
            </div>
          </div>
        </div>
      </OnClickOutside>

      <TabBar :tabs="viewTabs" :initial-active-tab="activeViewIndex" @tab-changed="handleTabChanged" />
      <Button icon="i-lucide-plus" :label="t('AGENDA.NEW_EVENT')" size="sm" @click="emit('create-event', {})" />
    </div>
  </div>
</template>
