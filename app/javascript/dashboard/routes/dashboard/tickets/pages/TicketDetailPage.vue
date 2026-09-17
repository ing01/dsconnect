<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { useTicketDetail } from '../composables/useTicketDetail';
import TicketDetailHeader from '../components/detail/TicketDetailHeader.vue';
import TicketOverviewTab from '../components/detail/TicketOverviewTab.vue';
import TicketCommunicationTab from '../components/detail/TicketCommunicationTab.vue';
import TicketAppointmentsTab from '../components/detail/TicketAppointmentsTab.vue';
import TicketChecklistsTab from '../components/detail/TicketChecklistsTab.vue';
import TicketTimeEntriesTab from '../components/detail/TicketTimeEntriesTab.vue';
import TicketDevelopmentTab from '../components/detail/TicketDevelopmentTab.vue';
import TicketHistoryTab from '../components/detail/TicketHistoryTab.vue';
import TicketTitleDialog from '../components/detail/actions/TicketTitleDialog.vue';
import TicketCompanyDialog from '../components/detail/actions/TicketCompanyDialog.vue';
import TicketContactDialog from '../components/detail/actions/TicketContactDialog.vue';
import TicketTransferDialog from '../components/detail/actions/TicketTransferDialog.vue';
import TicketConversationsDialog from '../components/detail/actions/TicketConversationsDialog.vue';
import TicketChildDialog from '../components/detail/actions/TicketChildDialog.vue';
import TicketCreateDialog from '../components/create/TicketCreateDialog.vue';
import TicketParentDialog from '../components/detail/actions/TicketParentDialog.vue';
import TicketMergeDialog from '../components/detail/actions/TicketMergeDialog.vue';
import TicketSlaHoursDialog from '../components/detail/actions/TicketSlaHoursDialog.vue';
import TicketBlockDialog from '../components/detail/actions/TicketBlockDialog.vue';
import TicketUnblockDialog from '../components/detail/actions/TicketUnblockDialog.vue';
import TicketCancelDialog from '../components/detail/actions/TicketCancelDialog.vue';
import TicketCloseDialog from '../components/detail/actions/TicketCloseDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const ticketId = computed(() => route.params.ticketId);

const {
  ticket,
  isLoading,
  canUpdate,
  canAddSlaHours,
  columns,
  categories,
  mesaAgents,
  usesAssigneeLevels,
  updateProperty,
  moveToColumn,
  changeStatus,
  transfer,
  setParent,
  merge,
  duplicate,
  assignToMe,
  adjustSla,
  cancel,
  block,
  unblock,
  reload,
} = useTicketDetail(ticketId);

const currentUser = useMapGetter('getCurrentUser');

const titleDialog = ref(null);
const companyDialog = ref(null);
const contactDialog = ref(null);
const transferDialog = ref(null);
const conversationsDialog = ref(null);
const childDialog = ref(null);
// The copy modal chooses what to carry over; the shared creation form then
// opens pre-filled with it. There is no separate child form.
const childCopyOptions = ref(null);
const showChildForm = ref(false);
const parentDialog = ref(null);
const mergeDialog = ref(null);
const slaDialog = ref(null);
const blockDialog = ref(null);
const unblockDialog = ref(null);
const cancelDialog = ref(null);
const closeDialog = ref(null);

const isActing = ref(false);

// Every dialog submit runs through here so a slow request cannot be fired twice
// and the dialog only closes once the server actually accepted the change.
const runAction = async (operation, dialog) => {
  if (isActing.value) return null;
  isActing.value = true;
  try {
    const result = await operation();
    if (result) dialog?.value?.close();
    return result;
  } finally {
    isActing.value = false;
  }
};

const goToTicket = created => {
  if (!created) return;
  router.push(
    frontendURL(`accounts/${route.params.accountId}/tickets/${created.id}`)
  );
};

// Quem responde por cada nivel neste ticket. Vazio quando a Mesa nao usa
// niveis, e ai a aba de apontamentos nao mostra o resumo por nivel.
const levelAssignees = computed(() => {
  if (!usesAssigneeLevels.value || !ticket.value) return {};

  return {
    1: ticket.value.assignee_name,
    2: ticket.value.assignee_2_name,
  };
});

const activeTab = ref('overview');
const isSavingDescription = ref(false);

const tabs = computed(() => [
  { value: 'overview', label: t('TICKET.DETAIL.TABS.OVERVIEW') },
  { value: 'communication', label: t('TICKET.DETAIL.TABS.COMMUNICATION') },
  { value: 'appointments', label: t('TICKET.DETAIL.TABS.APPOINTMENTS') },
  { value: 'checklists', label: t('TICKET.DETAIL.TABS.CHECKLISTS') },
  { value: 'time_entries', label: t('TICKET.DETAIL.TABS.TIME_ENTRIES') },
  { value: 'development', label: t('TICKET.DETAIL.TABS.DEVELOPMENT') },
  { value: 'history', label: t('TICKET.DETAIL.TABS.HISTORY') },
]);

const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab => tab.value === activeTab.value)
);

const onTabChange = tab => {
  activeTab.value = tab.value;
};

const goBack = () => {
  router.push(frontendURL(`accounts/${route.params.accountId}/tickets`));
};

const saveDescription = async description => {
  isSavingDescription.value = true;
  try {
    await updateProperty({ description });
  } finally {
    isSavingDescription.value = false;
  }
};

const STATUS_BY_ACTION = {
  reopen: 'open',
};

// Actions that only open a dialog. Closing and cancelling are confirmed first
// (they are terminal), so neither fires straight from the menu.
const DIALOG_BY_ACTION = {
  transfer: () => transferDialog,
  editTitle: () => titleDialog,
  editCompany: () => companyDialog,
  editContact: () => contactDialog,
  relatedConversations: () => conversationsDialog,
  createChild: () => childDialog,
  setParent: () => parentDialog,
  merge: () => mergeDialog,
  addSlaHours: () => slaDialog,
  block: () => blockDialog,
  unblock: () => unblockDialog,
  cancel: () => cancelDialog,
  close: () => closeDialog,
};

const handleAction = action => {
  const dialog = DIALOG_BY_ACTION[action];
  if (dialog) {
    dialog().value?.open();
  } else if (action === 'assignToMe') {
    runAction(() => assignToMe());
  } else if (action === 'duplicate') {
    runAction(() => duplicate()).then(goToTicket);
  } else if (STATUS_BY_ACTION[action]) {
    changeStatus(STATUS_BY_ACTION[action]);
  }
};

const submitTransfer = attributes =>
  runAction(() => transfer(attributes), transferDialog);

// The modal only collects the options. What it ticked decides which of the
// parent's values arrive pre-filled in the form, and which copies the server
// performs afterwards.
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
  goToTicket(created);
};

const submitParent = parentId =>
  runAction(() => setParent(parentId), parentDialog);

const submitMerge = sourceId => runAction(() => merge(sourceId), mergeDialog);

const submitSlaAdjustment = payload =>
  runAction(() => adjustSla(payload), slaDialog);

const submitBlock = reason => runAction(() => block(reason), blockDialog);
const submitUnblock = () => runAction(() => unblock(), unblockDialog);
const submitCancel = reason => runAction(() => cancel(reason), cancelDialog);

// Each of these edits one field in place, through the ticket's existing
// `update` endpoint - there is no generic ticket form any more.
const submitTitle = title =>
  runAction(() => updateProperty({ title }), titleDialog);

// One request: the Empresa and, when the current Solicitante does not belong to
// it, the cleared requester - the backend refuses the mismatched pair.
const submitCompany = ({ companyId, clearContact }) =>
  runAction(
    () =>
      updateProperty({
        company_id: companyId,
        ...(clearContact ? { contact_id: null } : {}),
      }),
    companyDialog
  );

const submitContact = contactId =>
  runAction(() => updateProperty({ contact_id: contactId }), contactDialog);
</script>

<template>
  <div
    class="flex flex-col w-full h-full min-h-0 min-w-0 p-4 gap-4 overflow-auto"
  >
    <div v-if="isLoading" class="flex items-center justify-center flex-1 gap-2">
      <Spinner />
      <span class="text-sm text-n-slate-11">{{ t('TICKET.LOADING') }}</span>
    </div>

    <template v-else-if="ticket">
      <TicketDetailHeader
        :ticket="ticket"
        :can-update="canUpdate"
        :can-add-sla-hours="canAddSlaHours"
        :current-user-id="currentUser.id"
        @back="goBack"
        @action="handleAction"
        @edit-title="handleAction('editTitle')"
      />

      <!-- The tab bar is `w-fit`, so on narrow screens it scrolls sideways
           instead of wrapping or hiding tabs. -->
      <div class="w-full min-w-0 overflow-x-auto -mx-1 px-1 flex-shrink-0">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChange"
        />
      </div>

      <TicketOverviewTab
        v-if="activeTab === 'overview'"
        :ticket="ticket"
        :columns="columns"
        :categories="categories"
        :agents="mesaAgents"
        :uses-assignee-levels="usesAssigneeLevels"
        :can-update="canUpdate"
        :is-saving-description="isSavingDescription"
        @save-description="saveDescription"
        @update-property="updateProperty"
        @move-to-column="moveToColumn"
        @change-status="changeStatus"
        @edit-company="handleAction('editCompany')"
        @edit-contact="handleAction('editContact')"
      />
      <TicketCommunicationTab
        v-else-if="activeTab === 'communication'"
        :ticket="ticket"
      />
      <TicketAppointmentsTab
        v-else-if="activeTab === 'appointments'"
        :ticket-id="ticket.id"
      />
      <TicketChecklistsTab
        v-else-if="activeTab === 'checklists'"
        :ticket-id="ticket.id"
      />
      <TicketTimeEntriesTab
        v-else-if="activeTab === 'time_entries'"
        :ticket-id="ticket.id"
        :level-assignees="levelAssignees"
      />
      <TicketDevelopmentTab v-else-if="activeTab === 'development'" />
      <TicketHistoryTab v-else :ticket-id="ticket.id" />

      <TicketTitleDialog
        ref="titleDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitTitle"
      />
      <TicketCompanyDialog
        ref="companyDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitCompany"
      />
      <TicketContactDialog
        ref="contactDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitContact"
      />
      <TicketTransferDialog
        ref="transferDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitTransfer"
      />
      <TicketConversationsDialog ref="conversationsDialog" :ticket="ticket" />
      <TicketChildDialog
        ref="childDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitChild"
      />
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

      <TicketParentDialog
        ref="parentDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitParent"
      />
      <TicketMergeDialog
        ref="mergeDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitMerge"
      />
      <TicketSlaHoursDialog
        ref="slaDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitSlaAdjustment"
      />
      <TicketBlockDialog
        ref="blockDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitBlock"
      />
      <TicketUnblockDialog
        ref="unblockDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitUnblock"
      />
      <TicketCancelDialog
        ref="cancelDialog"
        :ticket="ticket"
        :is-loading="isActing"
        @submit="submitCancel"
      />

      <!-- Closing requires a classification and a message that reached the
           customer, so it is a two-step flow rather than a confirmation. -->
      <TicketCloseDialog ref="closeDialog" :ticket="ticket" @closed="reload" />
    </template>
  </div>
</template>
