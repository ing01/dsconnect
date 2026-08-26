<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useTicketDetail } from '../../../composables/useTicketDetail';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketTransferDialog from './TicketTransferDialog.vue';
import TicketMergeDialog from './TicketMergeDialog.vue';
import TicketChildDialog from './TicketChildDialog.vue';
import TicketCloseDialog from './TicketCloseDialog.vue';
import TicketCreateDialog from '../../create/TicketCreateDialog.vue';
import TicketCustomerCommunication from '../TicketCustomerCommunication.vue';

// The ticket actions that make sense from anywhere - a Kanban card as much as
// the detail page. Both mount this, so there is one wiring rather than two.
//
// Everything here delegates to `useTicketDetail`, which is the same composable
// the detail page uses: same store actions, same permissions, same backend
// validations, same history and realtime.
const props = defineProps({
  // Null until a caller picks a ticket; the composable fetches the detail
  // payload the dialogs need (missing_close_requirements, customer_email...).
  ticketId: { type: [Number, String], default: null },
});

const emit = defineEmits(['changed']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const id = computed(() => props.ticketId);
const { ticket, transfer, merge, assignToMe, reload } = useTicketDetail(id);

const transferDialog = ref(null);
const mergeDialog = ref(null);
const childDialog = ref(null);
const closeDialog = ref(null);
const communicationDialog = ref(null);

const childCopyOptions = ref(null);
const showChildForm = ref(false);
const isActing = ref(false);

const isReady = computed(() => !!ticket.value);

// One place decides what each action opens, so the card menu and the detail
// menu cannot drift apart.
const DIALOGS = {
  transfer: () => transferDialog,
  merge: () => mergeDialog,
  createChild: () => childDialog,
  close: () => closeDialog,
  sendCommunication: () => communicationDialog,
};

const run = async (operation, dialog) => {
  if (isActing.value) return null;
  isActing.value = true;
  try {
    const result = await operation();
    if (result) {
      dialog?.value?.close();
      emit('changed', result);
    }
    return result;
  } finally {
    isActing.value = false;
  }
};

const open = action => {
  if (!isReady.value) return;

  if (action === 'assignToMe') {
    run(() => assignToMe());
    return;
  }

  DIALOGS[action]?.().value?.open();
};

const submitTransfer = attributes =>
  run(() => transfer(attributes), transferDialog);

const submitMerge = sourceId => run(() => merge(sourceId), mergeDialog);

// The copy modal only collects options; what it ticked decides which of the
// parent's values arrive pre-filled in the shared creation form.
const childContext = computed(() => {
  const options = childCopyOptions.value || {};
  const current = ticket.value || {};
  return {
    parentId: current.id,
    title: options.title ? current.title : '',
    description: options.description ? current.description : '',
    companyId: options.company ? current.company_id : null,
    companyName: options.company ? current.company_name : '',
    contactId: options.company ? current.contact?.id : null,
    contactName: options.company ? current.contact?.name : '',
    teamId: options.team ? current.team_id : null,
    assigneeId: options.team && options.assignee ? current.assignee_id : null,
    priority: current.priority || 'medium',
  };
});

const submitChild = ({ options }) => {
  childCopyOptions.value = options;
  childDialog.value?.close();
  showChildForm.value = true;
};

const closeChildForm = () => {
  showChildForm.value = false;
  childCopyOptions.value = null;
};

const onChildCreated = ({ ticket: created }) => {
  closeChildForm();
  emit('changed', created);
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${created.id}`)
  );
};

// The close flow refetches the ticket itself; the board is told so the card
// leaves it.
const onClosed = async () => {
  const updated = await reload();
  emit('changed', updated);
};

defineExpose({ open });
</script>

<template>
  <div v-if="isReady">
    <TicketTransferDialog
      ref="transferDialog"
      :ticket="ticket"
      :is-loading="isActing"
      @submit="submitTransfer"
    />
    <TicketMergeDialog
      ref="mergeDialog"
      :ticket="ticket"
      :is-loading="isActing"
      @submit="submitMerge"
    />
    <TicketChildDialog
      ref="childDialog"
      :ticket="ticket"
      :is-loading="isActing"
      @submit="submitChild"
    />
    <TicketCloseDialog ref="closeDialog" :ticket="ticket" @closed="onClosed" />

    <!-- The customer communication area itself, in a dialog. Same component the
         Comunicacao tab renders, so there is one composer. -->
    <Dialog
      ref="communicationDialog"
      width="2xl"
      overflow-y-auto
      :title="t('TICKET.COMMUNICATION.TAB.CUSTOMER')"
      :show-confirm-button="false"
      :cancel-button-label="t('TICKET.ACTIONS.CLOSE_DIALOG')"
    >
      <TicketCustomerCommunication :ticket="ticket" />
    </Dialog>

    <woot-modal
      v-model:show="showChildForm"
      :on-close="closeChildForm"
      size="large"
    >
      <TicketCreateDialog
        :parent-id="ticket.id"
        :copy-options="childCopyOptions"
        :context="childContext"
        @close="closeChildForm"
        @created="onChildCreated"
      />
    </woot-modal>
  </div>
</template>
