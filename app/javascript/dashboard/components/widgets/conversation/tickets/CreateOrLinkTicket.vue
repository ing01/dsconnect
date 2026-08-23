<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';
import TeamsAPI from 'dashboard/api/teams';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  linkedTicketIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['linked']);

const { t } = useI18n();
const store = useStore();

const mode = ref('link');
const isLoading = ref(false);
const isSubmitting = ref(false);
const searchQuery = ref('');
const allTickets = ref([]);
const teams = ref([]);
const selectedTeamId = ref(null);
const selectedColumnId = ref(null);
const newTitle = ref('');
const newTitleError = ref('');

const selectedTeamBoard = computed(() =>
  selectedTeamId.value
    ? store.getters['ticketColumns/getBoard'](selectedTeamId.value)
    : null
);
const columnsForSelectedTeam = computed(
  () => selectedTeamBoard.value?.ticket_columns || []
);

const filteredTickets = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return allTickets.value
    .filter(ticket => !props.linkedTicketIds.includes(ticket.id))
    .filter(ticket => !query || ticket.title.toLowerCase().includes(query));
});

const loadData = async () => {
  isLoading.value = true;
  try {
    const [ticketsResponse, teamsResponse] = await Promise.all([
      TicketsAPI.get(),
      TeamsAPI.get(),
    ]);
    allTickets.value = ticketsResponse.data?.payload || [];
    teams.value = teamsResponse.data || [];
    selectedTeamId.value = teams.value[0]?.id || null;
    if (selectedTeamId.value) {
      await store.dispatch('ticketColumns/fetchBoard', selectedTeamId.value);
    }
  } catch (error) {
    // Silent fail - the empty state covers this
  } finally {
    isLoading.value = false;
  }
};

// Whenever the selected Mesa changes (including on initial load), fetch its
// Estagios and default to the first one, but let the agent pick another.
watch(selectedTeamId, async teamId => {
  selectedColumnId.value = null;
  if (!teamId) return;
  await store.dispatch('ticketColumns/fetchBoard', teamId);
  selectedColumnId.value = columnsForSelectedTeam.value[0]?.id || null;
});

const linkTicket = async ticket => {
  try {
    await TicketsAPI.linkConversation(ticket.id, props.conversationId);
    emit('linked');
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  }
};

const createAndLinkTicket = async () => {
  if (!newTitle.value.trim()) {
    newTitleError.value = t('TICKET.FORM.TITLE.REQUIRED_ERROR');
    return;
  }
  if (!selectedColumnId.value) {
    useAlert(t('TICKET.CONVERSATION_PANEL.NO_BOARD_ERROR'));
    return;
  }

  isSubmitting.value = true;
  try {
    await TicketsAPI.createForConversation(props.conversationId, {
      title: newTitle.value.trim(),
      ticket_column_id: selectedColumnId.value,
      team_id: selectedTeamId.value,
    });
    emit('linked');
  } catch (error) {
    useAlert(t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};

onMounted(loadData);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="t('TICKET.CONVERSATION_PANEL.MODAL_TITLE')"
    />
    <div class="px-8 pb-8 flex flex-col gap-4">
      <div class="flex gap-2 border-b border-n-weak">
        <button
          type="button"
          class="px-1 pb-2 text-sm border-b-2"
          :class="
            mode === 'link'
              ? 'border-n-brand text-n-slate-12 font-medium'
              : 'border-transparent text-n-slate-11'
          "
          @click="mode = 'link'"
        >
          {{ t('TICKET.CONVERSATION_PANEL.LINK_EXISTING') }}
        </button>
        <button
          type="button"
          class="px-1 pb-2 text-sm border-b-2"
          :class="
            mode === 'create'
              ? 'border-n-brand text-n-slate-12 font-medium'
              : 'border-transparent text-n-slate-11'
          "
          @click="mode = 'create'"
        >
          {{ t('TICKET.CONVERSATION_PANEL.CREATE_NEW') }}
        </button>
      </div>

      <div v-if="isLoading" class="flex justify-center p-4">
        <Spinner />
      </div>

      <template v-else-if="mode === 'link'">
        <woot-input
          v-model="searchQuery"
          class="w-full"
          :placeholder="t('TICKET.CONVERSATION_PANEL.SEARCH_PLACEHOLDER')"
        />
        <p
          v-if="!filteredTickets.length"
          class="text-sm text-n-slate-11 text-center py-4"
        >
          {{ t('TICKET.CONVERSATION_PANEL.NO_RESULTS') }}
        </p>
        <div v-else class="max-h-64 overflow-y-auto flex flex-col gap-1">
          <button
            v-for="ticket in filteredTickets"
            :key="ticket.id"
            type="button"
            class="flex items-center justify-between gap-2 px-2 py-2 rounded-md hover:bg-n-slate-3 text-left"
            @click="linkTicket(ticket)"
          >
            <span class="text-sm text-n-slate-12 truncate">{{
              ticket.title
            }}</span>
            <NextButton
              slate
              faded
              xs
              :label="t('TICKET.CONVERSATION_PANEL.LINK_ACTION')"
            />
          </button>
        </div>
      </template>

      <template v-else>
        <woot-input
          v-model="newTitle"
          class="w-full"
          :label="t('TICKET.FORM.TITLE.LABEL')"
          :placeholder="t('TICKET.FORM.TITLE.PLACEHOLDER')"
          :error="newTitleError"
          @input="newTitleError = ''"
        />

        <p v-if="!teams.length" class="text-sm text-n-slate-11">
          {{ t('TICKET.CONVERSATION_PANEL.NO_BOARD_ERROR') }}
        </p>
        <div v-else class="flex w-full gap-3">
          <label class="w-1/2">
            <span class="text-sm text-n-slate-11">
              {{ t('TICKET.CONVERSATION_PANEL.BOARD_LABEL') }}
            </span>
            <select
              v-model="selectedTeamId"
              class="w-full mt-1 rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
            >
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </label>
          <label class="w-1/2">
            <span class="text-sm text-n-slate-11">
              {{ t('TICKET.CONVERSATION_PANEL.COLUMN_LABEL') }}
            </span>
            <select
              v-model="selectedColumnId"
              class="w-full mt-1 rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
            >
              <option
                v-for="column in columnsForSelectedTeam"
                :key="column.id"
                :value="column.id"
              >
                {{ column.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="flex items-center justify-end gap-2">
          <NextButton
            type="button"
            :is-loading="isSubmitting"
            :label="t('TICKET.FORM.CREATE')"
            @click="createAndLinkTicket"
          />
        </div>
      </template>
    </div>
  </div>
</template>
