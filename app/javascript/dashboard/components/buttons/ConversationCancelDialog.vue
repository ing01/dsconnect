<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  // Tickets em andamento ligados a conversa. Os que sao so' dela sao cancelados
  // junto, com o mesmo motivo; os que tem OUTRAS conversas
  // (`other_conversations_count` > 0) ficam a escolha de quem cancela.
  tickets: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const reason = ref('');

// O motivo e OBRIGATORIO: cancelar encerra em silencio (sem mensagem nem pesquisa
// ao cliente) e e' a unica justificativa que fica no historico.
const hasReason = computed(() => reason.value.trim().length > 0);

const exclusiveTickets = computed(() =>
  props.tickets.filter(ticket => !ticket.other_conversations_count)
);
const sharedTickets = computed(() =>
  props.tickets.filter(ticket => ticket.other_conversations_count > 0)
);

// Ticket compartilhado NAO e' cancelado por padrao: a conversa pode ser so' um
// dos assuntos dele, e cancelar o ticket e' decisao de quem esta cancelando.
const selectedSharedIds = ref([]);

const toggleShared = (ticketId, checked) => {
  selectedSharedIds.value = checked
    ? [...selectedSharedIds.value, ticketId]
    : selectedSharedIds.value.filter(id => id !== ticketId);
};

const open = () => {
  reason.value = '';
  selectedSharedIds.value = [];
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (!hasReason.value) return;

  emit('submit', {
    reason: reason.value.trim(),
    cancelTicketIds: selectedSharedIds.value,
  });
};

defineExpose({ open, close: () => dialogRef.value?.close() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="md"
    :title="t('CONVERSATION.CANCEL_DIALOG.TITLE')"
    :description="t('CONVERSATION.CANCEL_DIALOG.DESCRIPTION')"
    :cancel-button-label="t('CONVERSATION.CANCEL_DIALOG.BACK')"
    :confirm-button-label="t('CONVERSATION.CANCEL_DIALOG.CONFIRM')"
    :disable-confirm-button="!hasReason"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <label class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION.CANCEL_DIALOG.REASON')
          }}<span class="text-n-ruby-11">*</span>
        </span>
        <textarea
          v-model="reason"
          rows="3"
          class="w-full mb-0 cancel-reason"
          :placeholder="t('CONVERSATION.CANCEL_DIALOG.REASON_PLACEHOLDER')"
        />
      </label>

      <div
        v-if="exclusiveTickets.length"
        class="flex flex-col gap-1 p-3 text-sm rounded-lg bg-n-amber-3 text-n-amber-11 min-w-0"
      >
        <span class="font-medium">
          {{ t('CONVERSATION.CANCEL_DIALOG.TICKETS_WARNING') }}
        </span>
        <ul class="flex flex-col gap-0.5 m-0 list-none">
          <li
            v-for="ticket in exclusiveTickets"
            :key="ticket.id"
            class="truncate cancel-ticket"
            :title="ticket.title"
          >
            #{{ ticket.display_id }} - {{ ticket.title }}
          </li>
        </ul>
      </div>

      <!-- Ticket com mais de uma conversa: pergunta, em vez de cancelar por
           conta propria. Sem marcar nada, so' a conversa e' cancelada. -->
      <div
        v-if="sharedTickets.length"
        class="flex flex-col gap-2 p-3 text-sm border rounded-lg border-n-weak min-w-0"
      >
        <span class="font-medium text-n-slate-12">
          {{ t('CONVERSATION.CANCEL_DIALOG.SHARED_TICKETS_TITLE') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION.CANCEL_DIALOG.SHARED_TICKETS_HINT') }}
        </span>
        <label
          v-for="ticket in sharedTickets"
          :key="ticket.id"
          class="flex items-start gap-2 cursor-pointer min-w-0 shared-ticket"
        >
          <Checkbox
            class="mt-0.5 flex-shrink-0"
            :model-value="selectedSharedIds.includes(ticket.id)"
            @update:model-value="checked => toggleShared(ticket.id, checked)"
          />
          <span class="flex flex-col min-w-0">
            <span class="truncate text-n-slate-12" :title="ticket.title">
              #{{ ticket.display_id }} - {{ ticket.title }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                t(
                  'CONVERSATION.CANCEL_DIALOG.OTHER_CONVERSATIONS',
                  { count: ticket.other_conversations_count },
                  ticket.other_conversations_count
                )
              }}
            </span>
          </span>
        </label>
      </div>
    </div>
  </Dialog>
</template>
