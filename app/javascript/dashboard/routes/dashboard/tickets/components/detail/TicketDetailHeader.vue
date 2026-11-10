<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketActionsMenu from './TicketActionsMenu.vue';
import { statusColor } from '../../helpers/ticketLabels';

const props = defineProps({
  ticket: { type: Object, required: true },
  canUpdate: { type: Boolean, default: true },
  canAddSlaHours: { type: Boolean, default: false },
  currentUserId: { type: [Number, String], default: null },
});

const emit = defineEmits(['back', 'action', 'editTitle']);

const { t } = useI18n();

// `#NUM - [EMPRESA] | [SOLICITANTE] | [TÍTULO]`, skipping whichever parts this
// ticket doesn't have rather than rendering empty brackets.
const subject = computed(() =>
  [props.ticket.company_name, props.ticket.contact?.name, props.ticket.title]
    .filter(Boolean)
    .map(part => `[${part}]`)
    .join(' | ')
);

// `#NUM - Empresa | Solicitante | Título`, sem os colchetes da tela, pronto para
// colar em outro lugar.
const copyText = computed(() => {
  const parts = [
    props.ticket.company_name,
    props.ticket.contact?.name,
    props.ticket.title,
  ].filter(Boolean);
  return `#${props.ticket.display_id} - ${parts.join(' | ')}`;
});

const copyTitle = async () => {
  try {
    await copyTextToClipboard(copyText.value);
    useAlert(t('TICKET.DETAIL.COPY_TITLE_SUCCESS'));
  } catch (error) {
    // sem permissao de area de transferencia: nada a fazer
  }
};
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
      <!-- The title is edited where it is shown: clicking it opens the title
           dialog. The ticket number is not part of the button - it identifies
           the ticket and is not editable.

           `h1` is a real flex row here (not just `truncate` on the whole
           block): a long subject sitting inside a plain inline-block button
           has no width of its own for text-overflow to measure against, so
           it either rendered in full or got clipped with no ellipsis at all
           - barely anything showed. Giving the button its own `flex-1
           min-w-0` makes it a sized flex item that can truncate on its own
           text, the same pattern already used one level up (title vs. the
           status/actions group). -->
      <h1
        class="flex items-baseline gap-1 flex-1 min-w-0 text-lg font-medium text-n-slate-12"
      >
        <span class="flex-shrink-0 text-n-slate-10 font-normal">
          #{{ ticket.display_id }}
        </span>
        <button
          v-if="canUpdate"
          type="button"
          class="flex-1 min-w-0 text-left truncate transition-colors rounded hover:text-n-blue-11"
          :title="t('TICKET.ACTIONS.TITLE_DIALOG.EDIT_HINT')"
          @click="emit('editTitle')"
        >
          {{ subject }}
        </button>
        <span v-else class="flex-1 min-w-0 truncate">{{ subject }}</span>
        <button
          type="button"
          class="flex-shrink-0 self-center p-1 rounded text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          :title="t('TICKET.DETAIL.COPY_TITLE')"
          :aria-label="t('TICKET.DETAIL.COPY_TITLE')"
          @click="copyTitle"
        >
          <Icon icon="i-lucide-copy" class="size-4" />
        </button>
      </h1>

      <div class="flex items-center gap-2 flex-shrink-0">
        <!-- Impedido acompanha o status em vez de substitui-lo: um ticket
             impedido continua ABERTO, e trocar o selo faria parecer que ele
             saiu do fluxo. -->
        <WootLabel
          v-if="ticket.blocked"
          :label="t('TICKET.IMPEDIMENT.LABEL')"
          color="amber"
          compact
        />
        <WootLabel
          :label="t(`TICKET.STATUS.${ticket.status.toUpperCase()}`)"
          :color="statusColor(ticket.status)"
          compact
        />
        <TicketActionsMenu
          :ticket="ticket"
          :can-update="canUpdate"
          :can-add-sla-hours="canAddSlaHours"
          :current-user-id="currentUserId"
          @action="emit('action', $event)"
        />
      </div>
    </div>
  </header>
</template>
