<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketRequesterCard from './TicketRequesterCard.vue';
import TicketRelationshipsCard from './TicketRelationshipsCard.vue';
import TicketCatalogCard from './TicketCatalogCard.vue';
import TicketCompanyTicketsAccordion from './TicketCompanyTicketsAccordion.vue';
import TicketDescriptionCard from './TicketDescriptionCard.vue';
import TicketAttachmentsAccordion from './TicketAttachmentsAccordion.vue';
import TicketPropertiesCard from './TicketPropertiesCard.vue';
import TicketSlaAccordion from './TicketSlaAccordion.vue';

defineProps({
  ticket: { type: Object, required: true },
  columns: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  usesAssigneeLevels: { type: Boolean, default: false },
  categories: { type: Array, default: () => [] },
  canUpdate: { type: Boolean, default: true },
  isSavingDescription: { type: Boolean, default: false },
});

defineEmits([
  'saveDescription',
  'updateProperty',
  'moveToColumn',
  'changeStatus',
  'editCompany',
  'editContact',
]);
</script>

<template>
  <div class="flex flex-col gap-4 w-full min-w-0">
    <!-- O motivo do impedimento fica ACIMA das tres regioes e ocupa a largura
         toda: e a primeira coisa que precisa ser lida, e ela explica por que o
         ticket nao anda. Dentro de uma coluna, ficaria perdido entre cards. -->
    <div
      v-if="ticket.blocked"
      class="flex flex-col gap-1 p-4 border rounded-lg border-n-amber-4 bg-n-amber-2"
    >
      <div class="flex items-center gap-2 flex-wrap">
        <Icon icon="i-lucide-octagon-pause" class="size-4 text-n-amber-11" />
        <span class="text-sm font-medium text-n-amber-11">
          {{ $t('TICKET.IMPEDIMENT.TITLE') }}
        </span>
        <span v-if="blockedMeta" class="text-xs text-n-amber-11/80">
          {{ blockedMeta }}
        </span>
      </div>
      <p class="m-0 text-sm whitespace-pre-line text-n-slate-12">
        {{ ticket.blocked_reason }}
      </p>
    </div>

    <!-- Three regions on wide screens, two on tablets, one stacked column on
         phones. `min-w-0` on every region so a long value truncates instead of
         widening the grid. -->
    <div
      class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-[28fr_44fr_28fr] gap-4 w-full min-w-0"
    >
      <!-- On tablets the requester sits beside the properties, below the
         description, which is the reading order that matters there. -->
      <div class="flex flex-col gap-4 min-w-0 order-2 md:order-1 xl:order-none">
        <TicketRequesterCard
          :ticket="ticket"
          :can-update="canUpdate"
          @edit-company="$emit('editCompany')"
          @edit-contact="$emit('editContact')"
        />
        <TicketCatalogCard :ticket="ticket" />
        <TicketRelationshipsCard :ticket="ticket" />
        <TicketCompanyTicketsAccordion :ticket="ticket" />
        <TicketSlaAccordion :ticket="ticket" />
      </div>

      <div
        class="flex flex-col gap-4 min-w-0 order-1 md:order-none md:col-span-2 xl:col-span-1"
      >
        <TicketDescriptionCard
          :ticket="ticket"
          :can-update="canUpdate"
          :is-saving="isSavingDescription"
          @save="$emit('saveDescription', $event)"
        />
        <TicketAttachmentsAccordion
          :ticket-id="ticket.id"
          :can-update="canUpdate"
        />
      </div>

      <div class="flex flex-col gap-4 min-w-0 order-3 xl:order-none">
        <TicketPropertiesCard
          :ticket="ticket"
          :columns="columns"
          :categories="categories"
          :agents="agents"
          :uses-assignee-levels="usesAssigneeLevels"
          :can-update="canUpdate"
          @update-property="$emit('updateProperty', $event)"
          @move-to-column="$emit('moveToColumn', $event)"
          @change-status="$emit('changeStatus', $event)"
        />
      </div>
    </div>
  </div>
</template>
