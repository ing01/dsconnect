<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import AutomationFlowRunsAPI from 'dashboard/api/automationFlowRuns';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const isLoading = ref(true);
const runs = ref([]);
const expandedRunId = ref(null);

const hasRuns = computed(() => runs.value.length > 0);

const STATUS_COLORS = {
  running: 'blue',
  waiting: 'amber',
  completed: 'teal',
  handed_off: 'violet',
  failed: 'ruby',
};

const statusColor = status => STATUS_COLORS[status] || 'slate';

const load = async () => {
  isLoading.value = true;
  try {
    const response = await AutomationFlowRunsAPI.getByConversation(
      props.conversationId
    );
    runs.value = response.data?.payload || [];
    if (runs.value.length) expandedRunId.value = runs.value[0].id;
  } catch (error) {
    // Silencioso: este painel e' so um diagnostico auxiliar, nao pode ele
    // mesmo travar o resto da lateral se a conta nao tiver nenhum run ainda.
    runs.value = [];
  } finally {
    isLoading.value = false;
  }
};

const toggleRun = id => {
  expandedRunId.value = expandedRunId.value === id ? null : id;
};

const formatTime = seconds => {
  if (!seconds) return '';
  return new Date(seconds * 1000).toLocaleString();
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col gap-2">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>

    <p v-else-if="!hasRuns" class="text-sm text-n-slate-10">
      {{ t('AUTOMATION_FLOW_RUNS.EMPTY') }}
    </p>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="run in runs"
        :key="run.id"
        class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak bg-n-solid-1"
      >
        <button
          type="button"
          class="flex items-center justify-between w-full gap-2 text-left"
          @click="toggleRun(run.id)"
        >
          <div class="flex items-center gap-2 min-w-0">
            <WootLabel :label="run.status" :color="statusColor(run.status)" compact />
            <span class="text-xs truncate text-n-slate-11">
              {{ run.automation_rule_name }}
            </span>
          </div>
          <span class="flex-shrink-0 text-xs text-n-slate-10">{{ formatTime(run.created_at) }}</span>
        </button>

        <p v-if="run.current_step_id" class="text-xs text-n-slate-11">
          {{ t('AUTOMATION_FLOW_RUNS.CURRENT_STEP') }}:
          <span class="font-mono">{{ run.current_step_id }}</span>
        </p>

        <p v-if="run.last_error" class="text-xs break-words text-n-ruby-11">
          {{ run.last_error }}
        </p>

        <div v-if="expandedRunId === run.id" class="flex flex-col gap-1 pt-2 mt-1 border-t border-n-weak">
          <div
            v-for="event in run.events"
            :key="event.id"
            class="flex items-start gap-2 text-xs"
          >
            <WootLabel
              :label="event.outcome"
              :color="event.outcome === 'failed' ? 'ruby' : 'slate'"
              compact
            />
            <div class="min-w-0">
              <span class="font-mono text-n-slate-11">{{ event.step_id }}</span>
              <span class="text-n-slate-10"> ({{ event.step_type }})</span>
              <p v-if="event.error" class="break-words text-n-ruby-11">{{ event.error }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
