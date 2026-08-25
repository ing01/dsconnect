<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import TicketsAPI from 'dashboard/api/tickets';
import Accordion from 'dashboard/components-next/Accordion/Accordion.vue';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { statusColor } from '../../helpers/ticketLabels';

const props = defineProps({
  ticket: { type: Object, required: true },
});

const RECENT_LIMIT = 5;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const tickets = ref([]);
const isLoading = ref(false);
const hasLoaded = ref(false);

// Paginated `/tickets?company_id=` rather than `/companies/:id/tickets`: that
// one returns every ticket ordered by Kanban position, which is not "recent".
const load = async () => {
  if (!props.ticket.company_id || hasLoaded.value) return;

  isLoading.value = true;
  try {
    const { data } = await TicketsAPI.get({
      company_id: props.ticket.company_id,
      per_page: RECENT_LIMIT + 1,
      page: 1,
    });
    tickets.value = (data.payload || [])
      .filter(item => item.id !== props.ticket.id)
      .slice(0, RECENT_LIMIT);
    hasLoaded.value = true;
  } catch (error) {
    tickets.value = [];
  } finally {
    isLoading.value = false;
  }
};

const openTicket = ticketId => {
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${ticketId}`)
  );
};

const formatDate = timestamp =>
  timestamp ? new Date(timestamp * 1000).toLocaleDateString() : '';

watch(
  () => props.ticket.company_id,
  () => {
    hasLoaded.value = false;
    tickets.value = [];
  }
);
</script>

<template>
  <Accordion
    :title="t('TICKET.DETAIL.RECENT.TITLE')"
    @toggle="expanded => expanded && load()"
  >
    <div class="pt-2">
      <div v-if="isLoading" class="flex justify-center py-3">
        <Spinner :size="20" />
      </div>

      <p v-else-if="!ticket.company_id" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.RECENT.NO_COMPANY') }}
      </p>

      <p v-else-if="!tickets.length" class="text-sm text-n-slate-10">
        {{ t('TICKET.DETAIL.RECENT.EMPTY') }}
      </p>

      <ul v-else class="flex flex-col gap-1">
        <li v-for="item in tickets" :key="item.id">
          <button
            type="button"
            class="flex flex-col w-full gap-1 px-2 py-1.5 text-left rounded-lg hover:bg-n-alpha-2 transition-colors"
            @click="openTicket(item.id)"
          >
            <span class="flex items-center gap-2 min-w-0">
              <span class="text-xs text-n-slate-10 flex-shrink-0">
                #{{ item.display_id }}
              </span>
              <span
                class="text-sm text-n-slate-12 truncate"
                :title="item.title"
              >
                {{ item.title }}
              </span>
            </span>
            <span class="flex items-center gap-2">
              <WootLabel
                :label="t(`TICKET.STATUS.${item.status.toUpperCase()}`)"
                :color="statusColor(item.status)"
                compact
              />
              <span class="text-xs text-n-slate-10">
                {{ formatDate(item.created_at) }}
              </span>
            </span>
          </button>
        </li>
      </ul>
    </div>
  </Accordion>
</template>
