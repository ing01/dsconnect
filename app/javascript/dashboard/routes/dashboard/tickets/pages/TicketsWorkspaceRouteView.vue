<script setup>
import { watch } from 'vue';
import { useRoute } from 'vue-router';
import { rememberTicketList } from '../helpers/lastTicketList';

// Guarda a última lista aberta (Kanban, Backlog/Sprint ou Triagem) para o
// "Voltar" do ticket saber para onde ir.
const route = useRoute();
watch(() => route.fullPath, () => rememberTicketList(route), {
  immediate: true,
});
</script>

<template>
  <!-- The shell for the whole Tickets module. The tab bar no longer lives here:
       it is global (WorkspaceTabsBar, mounted by the Dashboard layout), so the
       Kanban, the Backlog and every open Ticket sit in the same bar.

       The Kanban (`TicketsPage`) IS kept alive, on purpose: a filter set on the
       board, or how far a column was scrolled, is work the agent did on that
       screen - opening a ticket from it and coming back must not throw that
       away. `include` scopes the cache to just that one page, so the detail
       page and the Triage queue keep unmounting/remounting exactly as before. -->
  <div class="flex flex-col w-full h-full min-h-0 min-w-0">
    <div class="flex flex-col flex-1 min-h-0 min-w-0">
      <router-view v-slot="{ Component }">
        <KeepAlive include="TicketsPage">
          <component :is="Component" />
        </KeepAlive>
      </router-view>
    </div>
  </div>
</template>
