<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useTicketWorkspace } from '../../composables/useTicketWorkspace';
import TicketWorkspaceTab from './TicketWorkspaceTab.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const { tabs, activeId, hasTabs, restore, openTab, closeTab, applyTicket } =
  useTicketWorkspace();

const currentUser = useMapGetter('getCurrentUser');
const ticketRecords = useMapGetter('tickets/getTicketsList');

const accountId = computed(() => route.params.accountId);
const routeTicketId = computed(() =>
  route.params.ticketId ? Number(route.params.ticketId) : null
);

const scroller = ref(null);
const canScroll = ref(false);

const kanbanPath = computed(() =>
  frontendURL(`accounts/${accountId.value}/tickets`)
);
const ticketPath = id =>
  frontendURL(`accounts/${accountId.value}/tickets/${id}`);

const isKanbanActive = computed(() => !routeTicketId.value);

// Renaming a Ticket, or moving it to another Empresa, rewrites its tab label as
// soon as the store has the new payload - no refresh, and no request of ours.
const syncLabels = () => (ticketRecords.value || []).forEach(applyTicket);

watch(ticketRecords, syncLabels, { deep: true });

// A new tab starts as a bare number; labelling it from what the store already
// holds spares the user that flash whenever the Ticket has been loaded before.
const openRouteTicket = id => {
  openTab(id);
  syncLabels();
};

// The bar follows the router rather than the click. Every screen that opens a
// Ticket - Kanban, Busca detalhada, Ultimos Tickets, a Conversation, a related
// Ticket - already navigates to its URL, so deriving the tab from the route
// covers all of them at once, and browser back/forward moves between open tabs
// without any of them being torn down.
// Not immediate: the restore below rebuilds the tab list from storage, so
// opening the route's Ticket before it has run would only be undone.
watch(routeTicketId, id => {
  if (id) openRouteTicket(id);
});

const selectTab = id => {
  if (id === routeTicketId.value) return;
  router.push(ticketPath(id));
};

// Closing a tab only removes it from this bar. The Ticket keeps its status, and
// nothing is sent to the server.
const onClose = id => {
  const next = closeTab(id);
  if (id !== routeTicketId.value) return;
  router.push(next ? ticketPath(next) : kanbanPath.value);
};

const updateScrollState = () => {
  const element = scroller.value;
  canScroll.value = !!element && element.scrollWidth > element.clientWidth + 1;
};

const scrollBy = direction => {
  scroller.value?.scrollBy({ left: direction * 240, behavior: 'smooth' });
};

// Keeps the tab the user just moved to in view, which matters most when it was
// reached with browser back/forward rather than by clicking a visible tab.
const revealActive = async () => {
  await nextTick();
  updateScrollState();
  const active = scroller.value?.querySelector('[data-active-tab="true"]');
  // Guarded rather than assumed: scrollIntoView is missing from some embedded
  // webviews, and a bar that cannot scroll itself is still a usable bar.
  if (typeof active?.scrollIntoView === 'function') {
    active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }
};

watch([activeId, tabs], revealActive, { deep: true });

onMounted(async () => {
  window.addEventListener('resize', updateScrollState);
  await restore(accountId.value, currentUser.value?.id);
  // The route wins over the persisted active id: a direct link must open the
  // Ticket it points at, not the one that happened to be active last session.
  if (routeTicketId.value) openRouteTicket(routeTicketId.value);
  revealActive();
});

onBeforeUnmount(() => window.removeEventListener('resize', updateScrollState));
</script>

<template>
  <div
    v-if="hasTabs"
    class="flex items-center w-full min-w-0 gap-2 flex-shrink-0"
  >
    <!-- The Kanban stays one click away, and reaching it closes nothing. -->
    <button
      type="button"
      class="flex items-center flex-shrink-0 h-9 gap-2 px-3 text-sm border rounded-lg transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="
        isKanbanActive
          ? 'border-n-brand bg-n-alpha-2 text-n-slate-12 font-medium'
          : 'border-n-weak bg-n-alpha-black2 text-n-slate-11 hover:border-n-slate-8'
      "
      @click="router.push(kanbanPath)"
    >
      <span class="i-lucide-kanban size-4" />
      {{ t('TICKET.WORKSPACE.KANBAN') }}
    </button>

    <button
      v-if="canScroll"
      type="button"
      class="flex items-center justify-center flex-shrink-0 rounded size-7 text-n-slate-11 hover:bg-n-alpha-2"
      :aria-label="t('TICKET.WORKSPACE.SCROLL_LEFT')"
      @click="scrollBy(-1)"
    >
      <span class="i-lucide-chevron-left size-4" />
    </button>

    <!-- Only this strip scrolls. The tabs keep their width instead of being
         squeezed thinner with every Ticket opened. -->
    <div
      ref="scroller"
      class="flex items-center min-w-0 gap-2 overflow-x-auto py-0.5"
      @scroll="updateScrollState"
    >
      <TicketWorkspaceTab
        v-for="tab in tabs"
        :key="tab.id"
        :tab="tab"
        :is-active="tab.id === routeTicketId"
        :data-active-tab="tab.id === routeTicketId ? 'true' : 'false'"
        @select="selectTab"
        @close="onClose"
      />
    </div>

    <button
      v-if="canScroll"
      type="button"
      class="flex items-center justify-center flex-shrink-0 rounded size-7 text-n-slate-11 hover:bg-n-alpha-2"
      :aria-label="t('TICKET.WORKSPACE.SCROLL_RIGHT')"
      @click="scrollBy(1)"
    >
      <span class="i-lucide-chevron-right size-4" />
    </button>
  </div>
</template>
