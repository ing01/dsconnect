<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  agents: {
    type: Array,
    default: () => [],
  },
  selectedAgentId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const isAllSelected = computed(() => !props.selectedAgentId);

const selectAgent = agentId => {
  emit('select', isAllSelected.value || props.selectedAgentId !== agentId ? agentId : null);
};
</script>

<template>
  <div class="flex items-center gap-1.5 overflow-x-auto pb-1 flex-shrink-0">
    <button
      type="button"
      class="flex items-center h-7 px-2.5 rounded-full text-xs font-medium border transition-colors flex-shrink-0"
      :class="
        isAllSelected
          ? 'bg-n-brand/10 border-n-brand text-n-blue-11'
          : 'border-n-weak text-n-slate-11 hover:bg-n-slate-3'
      "
      @click="emit('select', null)"
    >
      {{ t('TICKET.FILTERS.ALL_AGENTS') }}
    </button>

    <button
      v-for="agent in agents"
      :key="agent.id"
      type="button"
      v-tooltip="agent.name"
      class="flex-shrink-0 rounded-full transition-shadow"
      :class="
        selectedAgentId === agent.id
          ? 'ring-2 ring-n-brand ring-offset-1 ring-offset-n-background'
          : 'opacity-70 hover:opacity-100'
      "
      @click="selectAgent(agent.id)"
    >
      <Avatar :name="agent.name" :src="agent.thumbnail" :size="28" rounded-full hide-offline-status />
    </button>
  </div>
</template>
