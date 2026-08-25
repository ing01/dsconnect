<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import CompaniesAPI from 'dashboard/api/companies';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  companyId: { type: [Number, String], default: null },
});

// Deliberately few: this is here to catch a duplicate before one is opened, not
// to be a second ticket list.
const LIMIT = 5;

const { t } = useI18n();
const route = useRoute();

const tickets = ref([]);
const isLoading = ref(false);

let token = 0;

const load = async companyId => {
  tickets.value = [];
  if (!companyId) return;

  token += 1;
  const current = token;
  isLoading.value = true;
  try {
    const response = await CompaniesAPI.listTickets(companyId);
    // A slower earlier request must not overwrite a newer one's results.
    if (current !== token) return;
    tickets.value = (response.data?.payload ?? []).slice(0, LIMIT);
  } catch (error) {
    if (current === token) tickets.value = [];
  } finally {
    if (current === token) isLoading.value = false;
  }
};

const ticketPath = ticket =>
  frontendURL(`accounts/${route.params.accountId}/tickets/${ticket.id}`);

watch(() => props.companyId, load, { immediate: true });
</script>

<template>
  <section class="flex flex-col gap-2 min-w-0">
    <h3 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.CREATE.RECENT.TITLE') }}
    </h3>

    <div v-if="isLoading" class="flex justify-center py-3">
      <Spinner :size="20" />
    </div>

    <p v-else-if="!companyId" class="text-xs text-n-slate-10">
      {{ t('TICKET.CREATE.RECENT.NEEDS_COMPANY') }}
    </p>

    <p v-else-if="!tickets.length" class="text-xs text-n-slate-10">
      {{ t('TICKET.CREATE.RECENT.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-1 min-w-0">
      <li v-for="ticket in tickets" :key="ticket.id" class="min-w-0">
        <!-- Opens in a new tab on purpose: checking a possible duplicate must
             not throw away the ticket being written. -->
        <router-link
          :to="ticketPath(ticket)"
          target="_blank"
          class="flex gap-1 text-xs truncate text-n-slate-11 hover:text-n-blue-11"
          :title="ticket.title"
        >
          <span class="flex-shrink-0 text-n-slate-10">
            #{{ ticket.display_id }}
          </span>
          <span class="truncate">{{ ticket.title }}</span>
        </router-link>
      </li>
    </ul>
  </section>
</template>
