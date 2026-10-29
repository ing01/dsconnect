<script setup>
import { watch } from 'vue';
import { useRoute } from 'vue-router';
import TicketWorkspaceTabs from '../components/workspace/TicketWorkspaceTabs.vue';
import { rememberTicketList } from '../helpers/lastTicketList';

// Guarda a última lista aberta (Kanban, Backlog/Sprint ou Triagem) para o
// "Voltar" do ticket saber para onde ir.
const route = useRoute();
watch(() => route.fullPath, () => rememberTicketList(route), {
  immediate: true,
});
</script>

<template>
  <!-- The workspace shell for the whole Tickets module. The bar lives here, one
       level above both the Kanban and the detail page, so moving between them
       is an ordinary route change that never unmounts it. Only the active
       Ticket is rendered: the other tabs are navigation state, not pages kept
       alive in the DOM.

       The Kanban (`TicketsPage`) IS kept alive, on purpose: a filter set on the
       board, or how far a column was scrolled, is work the agent did on that
       screen - opening a ticket from it and coming back must not throw that
       away. `include` scopes the cache to just that one page, so the detail
       page and the Triage queue keep unmounting/remounting exactly as before. -->
  <div class="flex flex-col w-full h-full min-h-0 min-w-0">
    <div class="px-4 pt-4 empty:hidden">
      <TicketWorkspaceTabs />
    </div>

    <div class="flex flex-col flex-1 min-h-0 min-w-0">
      <router-view v-slot="{ Component }">
        <KeepAlive include="TicketsPage">
          <component :is="Component" />
        </KeepAlive>
      </router-view>
    </div>
  </div>
</template>
