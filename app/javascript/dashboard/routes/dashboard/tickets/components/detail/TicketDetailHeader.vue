<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketActionsMenu from './TicketActionsMenu.vue';
import { statusColor } from '../../helpers/ticketLabels';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
});

const emit = defineEmits(['back', 'action']);

const { t } = useI18n();

// `#NUM - [EMPRESA] | [SOLICITANTE] | [TÍTULO]`, skipping whichever parts this
// ticket doesn't have rather than rendering empty brackets.
const subject = computed(() =>
  [props.ticket.company_name, props.ticket.contact?.name, props.ticket.title]
    .filter(Boolean)
    .map(part => `[${part}]`)
    .join(' | ')
);
</script>

<template>
  <header class="flex flex-col gap-3 w-full min-w-0">
    <button
      type="button"
      class="flex items-center gap-1 text-sm text-n-slate-11 hover:text-n-slate-12 transition-colors w-fit"
      @click="emit('back')"
    >
      <Icon icon="i-lucide-arrow-left" class="size-4" />
      {{ t('TICKET.DETAIL.BACK') }}
    </button>

    <!-- The title takes the slack and truncates; status and actions never
         shrink, so a long subject can't push them past the viewport. -->
    <div
      class="flex items-start justify-between gap-3 w-full min-w-0 flex-wrap"
    >
      <h1
        class="flex-1 min-w-0 text-lg font-medium text-n-slate-12 truncate"
        :title="`#${ticket.display_id} - ${subject}`"
      >
        <span class="text-n-slate-10 font-normal">
          #{{ ticket.display_id }}
        </span>
        {{ subject }}
      </h1>

      <div class="flex items-center gap-2 flex-shrink-0">
        <WootLabel
          :label="t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
          :color="statusColor(ticket.status)"
          compact
        />
        <TicketActionsMenu
          :ticket="ticket"
          :can-update="canUpdate"
          @action="emit('action', $event)"
        />
      </div>
    </div>
  </header>
</template>
