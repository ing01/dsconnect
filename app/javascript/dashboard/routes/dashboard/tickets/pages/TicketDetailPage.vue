<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import { useTicketDetail } from '../composables/useTicketDetail';
import TicketDetailHeader from '../components/detail/TicketDetailHeader.vue';
import TicketOverviewTab from '../components/detail/TicketOverviewTab.vue';
import TicketCommunicationTab from '../components/detail/TicketCommunicationTab.vue';
import TicketAppointmentsTab from '../components/detail/TicketAppointmentsTab.vue';
import TicketChecklistsTab from '../components/detail/TicketChecklistsTab.vue';
import TicketDevelopmentTab from '../components/detail/TicketDevelopmentTab.vue';
import TicketHistoryTab from '../components/detail/TicketHistoryTab.vue';
import TicketFormDialog from '../components/TicketFormDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const ticketId = computed(() => route.params.ticketId);

const {
  ticket,
  isLoading,
  canUpdate,
  columns,
  mesaAgents,
  updateProperty,
  moveToColumn,
  changeStatus,
} = useTicketDetail(ticketId);

const activeTab = ref('overview');
const isSavingDescription = ref(false);
const showEditForm = ref(false);

const tabs = computed(() => [
  { value: 'overview', label: t('TICKET.DETAIL.TABS.OVERVIEW') },
  { value: 'communication', label: t('TICKET.DETAIL.TABS.COMMUNICATION') },
  { value: 'appointments', label: t('TICKET.DETAIL.TABS.APPOINTMENTS') },
  { value: 'checklists', label: t('TICKET.DETAIL.TABS.CHECKLISTS') },
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

const submitEdit = async payload => {
  await updateProperty(payload);
  showEditForm.value = false;
};

const openFirstConversation = () => {
  const conversation = (ticket.value?.conversations || [])[0];
  if (!conversation) return;
  router.push(
    frontendURL(
      `accounts/${route.params.accountId}/conversations/${conversation.display_id}`
    )
  );
};

const copyLink = async () => {
  try {
    await navigator.clipboard.writeText(window.location.href);
    useAlert(t('TICKET.DETAIL.ACTIONS.LINK_COPIED'));
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  }
};

const STATUS_BY_ACTION = {
  resolve: 'resolved',
  close: 'closed',
  reopen: 'open',
};

const handleAction = action => {
  if (action === 'edit') {
    showEditForm.value = true;
  } else if (action === 'openConversation') {
    openFirstConversation();
  } else if (action === 'copyLink') {
    copyLink();
  } else if (STATUS_BY_ACTION[action]) {
    changeStatus(STATUS_BY_ACTION[action]);
  }
};

// The Kanban already refetches the board when a ticket changes, so leaving the
// detail page never needs an explicit refresh.
const closeEditForm = () => {
  showEditForm.value = false;
};

const onModalUpdate = () => {
  store.dispatch('tickets/fetchActivities', ticketId.value);
};
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
        @back="goBack"
        @action="handleAction"
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
        :agents="mesaAgents"
        :can-update="canUpdate"
        :is-saving-description="isSavingDescription"
        @save-description="saveDescription"
        @update-property="updateProperty"
        @move-to-column="moveToColumn"
        @change-status="changeStatus"
      />
      <TicketCommunicationTab
        v-else-if="activeTab === 'communication'"
        :ticket="ticket"
      />
      <TicketAppointmentsTab
        v-else-if="activeTab === 'appointments'"
        :ticket-id="ticket.id"
      />
      <TicketChecklistsTab v-else-if="activeTab === 'checklists'" />
      <TicketDevelopmentTab v-else-if="activeTab === 'development'" />
      <TicketHistoryTab v-else :ticket-id="ticket.id" />

      <woot-modal v-model:show="showEditForm" :on-close="closeEditForm">
        <TicketFormDialog
          :ticket="ticket"
          :agents="mesaAgents"
          @close="closeEditForm"
          @submit="submitEdit"
          @update="onModalUpdate"
        />
      </woot-modal>
    </template>
  </div>
</template>
