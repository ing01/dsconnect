<script setup>
import TicketWorkspaceTabs from '../components/workspace/TicketWorkspaceTabs.vue';
</script>

<template>
  <!-- The workspace shell for the whole Tickets module. The bar lives here, one
       level above both the Kanban and the detail page, so moving between them
       is an ordinary route change that never unmounts it. Only the active
       Ticket is rendered: the other tabs are navigation state, not pages kept
       alive in the DOM. -->
  <div class="flex flex-col w-full h-full min-h-0 min-w-0">
    <div class="px-4 pt-4 empty:hidden">
      <TicketWorkspaceTabs />
    </div>

    <div class="flex flex-col flex-1 min-h-0 min-w-0">
      <router-view />
    </div>
  </div>
</template>
