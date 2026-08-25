<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import wootConstants from 'dashboard/constants/globals';
import TicketsAPI from 'dashboard/api/tickets';
import TicketCreateDialog from 'dashboard/routes/dashboard/tickets/components/create/TicketCreateDialog.vue';
import LinkExistingTicket from './LinkExistingTicket.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  // The panel itself is toggled by the header button it is anchored to. This
  // component stays mounted either way, so the form modals below survive the
  // panel closing.
  isOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'count']);

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');

const tickets = ref([]);
const isLoading = ref(false);
// Two levels in one panel: the linked tickets, and the add menu.
const level = ref('list');
const shouldShowCreateModal = ref(false);
const shouldShowLinkModal = ref(false);
// Set when the chosen flow ends by closing the conversation. The conversation is
// only resolved AFTER the ticket exists and is linked, never before.
const resolveAfterwards = ref(false);

const hasTickets = computed(() => tickets.value.length > 0);
const linkedTicketIds = computed(() => tickets.value.map(ticket => ticket.id));

// Only tickets of the Empresa this conversation's contact belongs to may be
// linked, so the Empresa comes from the contact, not from the agent.
const contact = computed(() => currentChat.value?.meta?.sender || {});
const companyId = computed(() => contact.value.company_id || null);
const companyName = computed(
  () => contact.value.company?.name || contact.value.company_name || ''
);

// Everything the chat already knows, so the analyst does not pick it again. The
// Empresa only carries over when the contact actually belongs to one; otherwise
// the form asks for it.
const creationContext = computed(() => ({
  companyId: companyId.value,
  companyName: companyName.value,
  contactId: companyId.value ? contact.value.id : null,
  contactName: contact.value.name || '',
}));

// The four flows are two choices crossed: create a ticket or link an existing
// one, and afterwards keep the chat open or close it. The two that close it are
// grouped apart - set off by a separator and their own icon, not by looking
// destructive, because resolving a conversation is routine.
const ADD_ACTIONS = [
  { value: 'createKeepOpen', flow: 'create', resolve: false, icon: 'i-lucide-plus' },
  { value: 'linkKeepOpen', flow: 'link', resolve: false, icon: 'i-lucide-link' },
  { value: 'createAndResolve', flow: 'create', resolve: true, icon: 'i-lucide-circle-check' },
  { value: 'linkAndResolve', flow: 'link', resolve: true, icon: 'i-lucide-circle-check' },
];

const keepOpenActions = computed(() =>
  ADD_ACTIONS.filter(action => !action.resolve)
);
const resolveActions = computed(() =>
  ADD_ACTIONS.filter(action => action.resolve)
);

const labelFor = action =>
  t(`TICKET.CONVERSATION_PANEL.ADD_MENU.${action.value.toUpperCase()}`);

const loadTickets = async () => {
  isLoading.value = true;
  try {
    const response = await TicketsAPI.getByConversation(props.conversationId);
    tickets.value = response.data?.payload || [];
    emit('count', tickets.value.length);
  } catch (error) {
    // Silent fail - not critical for UX
  } finally {
    isLoading.value = false;
  }
};

const openTicket = ticket => {
  emit('close');
  router.push(
    frontendURL(`accounts/${currentAccountId.value}/tickets/${ticket.id}`)
  );
};

const unlinkTicket = async ticketId => {
  try {
    await TicketsAPI.unlinkConversation(ticketId, props.conversationId);
    tickets.value = tickets.value.filter(ticket => ticket.id !== ticketId);
    emit('count', tickets.value.length);
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  }
};

const chooseAction = action => {
  resolveAfterwards.value = action.resolve;
  shouldShowCreateModal.value = action.flow === 'create';
  shouldShowLinkModal.value = action.flow === 'link';
  emit('close');
};

const closeModals = () => {
  shouldShowCreateModal.value = false;
  shouldShowLinkModal.value = false;
  resolveAfterwards.value = false;
  loadTickets();
};

// Runs only once the ticket is created/linked, so a failure on that side leaves
// the conversation exactly as it was. Uses the same `toggleStatus` action the
// Resolver button uses - no parallel mechanism.
const onTicketLinked = async () => {
  const shouldResolve = resolveAfterwards.value;
  closeModals();

  if (!shouldResolve) return;

  await store.dispatch('toggleStatus', {
    conversationId: props.conversationId,
    status: wootConstants.STATUS_TYPE.RESOLVED,
  });
};

// The panel always opens on the list; the add menu is somewhere the agent chose
// to go, not a state that outlives the panel.
watch(
  () => props.isOpen,
  open => {
    if (open) level.value = 'list';
  }
);

watch(
  () => props.conversationId,
  () => loadTickets()
);

onMounted(loadTickets);
</script>

<template>
  <div>
    <!-- Same surface tokens the dropdown menus use, so it follows the theme in
         both modes. Width is fixed and modest; only the linked list scrolls,
         and only once there are more items than fit. -->
    <div
      v-if="isOpen"
      class="absolute z-50 flex flex-col w-72 max-w-[calc(100vw-2rem)] mt-1 top-full ltr:right-0 rtl:left-0 text-sm border rounded-xl shadow-md bg-n-alpha-3 backdrop-blur-[100px] border-n-weak"
    >
      <template v-if="level === 'list'">
        <h3
          class="px-3 pt-3 pb-2 text-sm font-medium text-n-slate-12 truncate"
        >
          {{ t('CONVERSATION_SIDEBAR.ACCORDION.TICKETS') }}
        </h3>

        <div v-if="isLoading" class="flex justify-center py-6">
          <Spinner />
        </div>

        <p v-else-if="!hasTickets" class="px-3 pb-3 text-sm text-n-slate-11">
          {{ t('TICKET.CONVERSATION_PANEL.NO_LINKED_TICKETS') }}
        </p>

        <template v-else>
          <p
            class="px-3 pb-1 text-xs tracking-wide uppercase text-n-slate-10"
          >
            {{ t('TICKET.CONVERSATION_PANEL.LINKED_TITLE') }}
          </p>
          <ul class="flex flex-col px-1 pb-2 overflow-y-auto max-h-56">
            <li
              v-for="ticket in tickets"
              :key="ticket.id"
              class="flex items-center gap-1 group"
            >
              <button
                type="button"
                class="flex-1 min-w-0 px-2 py-1.5 text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
                :title="ticket.title"
                @click="openTicket(ticket)"
              >
                <span class="text-n-slate-10">#{{ ticket.display_id }}</span>
                <span class="truncate"> - {{ ticket.title }}</span>
              </button>
              <button
                type="button"
                class="flex-shrink-0 p-1 transition-opacity rounded-lg opacity-0 text-n-slate-11 hover:bg-n-alpha-2 group-hover:opacity-100 focus:opacity-100"
                :aria-label="t('TICKET.CONVERSATION_PANEL.UNLINK')"
                @click="unlinkTicket(ticket.id)"
              >
                <Icon icon="i-lucide-x" class="size-3.5" />
              </button>
            </li>
          </ul>
        </template>

        <div class="h-px mx-2 bg-n-weak" />

        <button
          type="button"
          data-role="add"
          class="flex items-center gap-2 px-3 py-2.5 m-1 text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
          @click="level = 'actions'"
        >
          <Icon icon="i-lucide-plus" class="flex-shrink-0 size-4" />
          {{ t('TICKET.CONVERSATION_PANEL.ADD_BUTTON') }}
        </button>
      </template>

      <template v-else>
        <!-- Going back returns to the list rather than closing the panel, so a
             wrong turn costs one click. -->
        <!-- Echoes the action name, so the submenu still says what it is for;
             the marker is what tells the two apart. -->
        <button
          type="button"
          data-role="back"
          class="flex items-center gap-1 px-3 pt-3 pb-2 text-sm font-medium text-left text-n-slate-12"
          @click="level = 'list'"
        >
          <Icon icon="i-lucide-chevron-left" class="flex-shrink-0 size-4" />
          {{ t('TICKET.CONVERSATION_PANEL.ADD_BUTTON') }}
        </button>

        <div class="flex flex-col p-1">
          <button
            v-for="action in keepOpenActions"
            :key="action.value"
            type="button"
            :data-action="action.value"
            class="flex items-center gap-2 px-2 py-2 text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
            @click="chooseAction(action)"
          >
            <Icon
              :icon="action.icon"
              class="flex-shrink-0 size-4 text-n-slate-11"
            />
            <span class="min-w-0">{{ labelFor(action) }}</span>
          </button>
        </div>

        <div class="h-px mx-2 bg-n-weak" />

        <!-- Resolving a conversation is routine, so these are set apart by a
             heading and a check icon - never by destructive colouring. -->
        <p class="px-3 pt-2 text-xs tracking-wide uppercase text-n-slate-10">
          {{ t('TICKET.CONVERSATION_PANEL.RESOLVE_GROUP') }}
        </p>
        <div class="flex flex-col p-1">
          <button
            v-for="action in resolveActions"
            :key="action.value"
            type="button"
            :data-action="action.value"
            class="flex items-center gap-2 px-2 py-2 text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
            @click="chooseAction(action)"
          >
            <Icon
              :icon="action.icon"
              class="flex-shrink-0 size-4 text-n-slate-11"
            />
            <span class="min-w-0">{{ labelFor(action) }}</span>
          </button>
        </div>
      </template>
    </div>

    <!-- Rendered outside the panel so closing it never unmounts an open form.
         The creation form is the same one the Kanban and the child flow use;
         the menu only decides what happens once it succeeds. -->
    <woot-modal
      v-model:show="shouldShowCreateModal"
      :on-close="closeModals"
      :close-on-backdrop-click="false"
      size="large"
    >
      <TicketCreateDialog
        :conversation-id="conversationId"
        :context="creationContext"
        @close="closeModals"
        @created="onTicketLinked"
      />
    </woot-modal>

    <woot-modal
      v-model:show="shouldShowLinkModal"
      :on-close="closeModals"
      :close-on-backdrop-click="false"
    >
      <LinkExistingTicket
        :conversation-id="conversationId"
        :company-id="companyId"
        :company-name="companyName"
        :linked-ticket-ids="linkedTicketIds"
        @close="closeModals"
        @linked="onTicketLinked"
      />
    </woot-modal>
  </div>
</template>
