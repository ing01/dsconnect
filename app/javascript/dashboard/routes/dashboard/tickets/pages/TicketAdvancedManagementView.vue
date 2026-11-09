<script setup>
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import TicketDetailedSearchModal from '../components/TicketDetailedSearchModal.vue';

const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');

onMounted(() => {
  if (!teams.value.length) store.dispatch('teams/get');
});
</script>

<template>
  <div
    class="flex flex-col w-full h-full min-h-0 overflow-y-auto bg-n-background"
  >
    <div class="px-6 pt-6">
      <h1 class="m-0 text-xl font-medium text-n-slate-12">
        {{ t('TICKET.ADVANCED_MANAGEMENT.TITLE') }}
      </h1>
    </div>
    <TicketDetailedSearchModal :teams="teams" :show-header="false" />
  </div>
</template>
