<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Select from 'dashboard/components-next/select/Select.vue';

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
});

const emit = defineEmits(['select-team', 'change-view', 'navigate-previous', 'navigate-next', 'navigate-today', 'create-event']);

const { t } = useI18n();

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
      <TabBar :tabs="viewTabs" :initial-active-tab="activeViewIndex" @tab-changed="handleTabChanged" />
      <Button icon="i-lucide-plus" :label="t('AGENDA.NEW_EVENT')" size="sm" @click="emit('create-event', {})" />
    </div>
  </div>
</template>
