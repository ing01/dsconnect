<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import HelpdeskOverviewAPI from 'dashboard/api/helpdeskOverview';
import ReportHeader from './components/ReportHeader.vue';
import MetricCard from './components/overview/MetricCard.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const teams = computed(() => getters['teams/getTeams'].value);
const queues = computed(() => getters['queues/getQueues'].value);

const isLoading = ref(true);
const overview = ref({ conversations: {}, tickets: {}, sla: {} });

const teamName = id => teams.value.find(team => team.id === Number(id))?.name || `#${id}`;
const queueName = id => queues.value.find(queue => queue.id === Number(id))?.name || `#${id}`;

const fetchOverview = async () => {
  try {
    const response = await HelpdeskOverviewAPI.get();
    overview.value = response.data;
  } finally {
    isLoading.value = false;
  }
};

const { startRefetching } = useLiveRefresh(fetchOverview, 30000);

onMounted(async () => {
  await fetchOverview();
  startRefetching();
});

const conversationsByStatus = computed(() => Object.entries(overview.value.conversations?.by_status || {}));
const conversationsByTeam = computed(() =>
  Object.entries(overview.value.conversations?.by_team || {}).map(([id, count]) => [teamName(id), count])
);
const conversationsByQueue = computed(() =>
  Object.entries(overview.value.conversations?.by_queue || {}).map(([id, count]) => [queueName(id), count])
);
const ticketsByStatus = computed(() => Object.entries(overview.value.tickets?.by_status || {}));
const ticketsByTeam = computed(() =>
  Object.entries(overview.value.tickets?.by_team || {}).map(([id, count]) => [teamName(id), count])
);
const slaByStatus = computed(() => Object.entries(overview.value.sla?.by_status || {}));
</script>

<template>
  <div class="flex-1 overflow-auto">
    <ReportHeader :header-title="$t('HELPDESK_OVERVIEW.HEADER')" />
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 p-6">
      <MetricCard :header="$t('HELPDESK_OVERVIEW.CONVERSATIONS_BY_STATUS')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in conversationsByStatus" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>

      <MetricCard :header="$t('HELPDESK_OVERVIEW.CONVERSATIONS_BY_TEAM')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in conversationsByTeam" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>

      <MetricCard :header="$t('HELPDESK_OVERVIEW.CONVERSATIONS_BY_QUEUE')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in conversationsByQueue" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>

      <MetricCard :header="$t('HELPDESK_OVERVIEW.TICKETS_BY_STATUS')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in ticketsByStatus" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>

      <MetricCard :header="$t('HELPDESK_OVERVIEW.TICKETS_BY_TEAM')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in ticketsByTeam" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>

      <MetricCard v-if="slaByStatus.length" :header="$t('HELPDESK_OVERVIEW.SLA_BY_STATUS')" :is-loading="isLoading">
        <div class="w-full flex flex-col gap-2">
          <div v-for="[key, count] in slaByStatus" :key="key" class="flex justify-between">
            <span class="text-n-slate-11">{{ key }}</span>
            <span class="font-medium">{{ count }}</span>
          </div>
        </div>
      </MetricCard>
    </div>
  </div>
</template>
