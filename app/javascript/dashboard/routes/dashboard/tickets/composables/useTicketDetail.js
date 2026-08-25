import { computed, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

// Everything the detail page needs to read and mutate one ticket, so the page
// itself stays a layout shell.
export function useTicketDetail(ticketId) {
  const store = useStore();
  const { t } = useI18n();

  const ticket = computed(() =>
    store.getters['tickets/getTicket'](ticketId.value)
  );
  const uiFlags = useMapGetter('tickets/getUIFlags');
  const isLoading = computed(
    () => uiFlags.value.isFetchingItem && !ticket.value
  );

  // TicketPolicy#update? is administrator || assignee || Mesa member. The server
  // sends the verdict so the controls render disabled instead of failing on save.
  const canUpdate = computed(() => ticket.value?.can_update !== false);

  // Estagios of the ticket's own Mesa. Fetched through the lean columns index -
  // pulling the Kanban board just to populate a select costs the whole payload.
  const columns = computed(
    () => store.getters['ticketColumns/getColumns'](ticket.value?.team_id) || []
  );

  const mesaAgents = computed(
    () =>
      store.getters['teamMembers/getTeamMembers'](ticket.value?.team_id) || []
  );

  const loadTicket = async () => {
    const loaded = await store.dispatch('tickets/fetchTicket', ticketId.value);
    return loaded;
  };

  const loadMesaContext = teamId => {
    if (!teamId) return;
    store.dispatch('teamMembers/get', { teamId });
    store.dispatch('ticketColumns/fetchColumns', teamId);
  };

  // Every mutation funnels through here: push the fresh payload into the Kanban
  // store so the board reflects it without waiting for the realtime round-trip,
  // and refresh the history so the Historico tab stays honest.
  const applyUpdate = updated => {
    if (!updated) return;
    store.dispatch('ticketColumns/applyRealtimeTicket', updated);
    store.dispatch('tickets/fetchActivities', ticketId.value);
  };

  const runUpdate = async (action, payload) => {
    try {
      const updated = await store.dispatch(action, payload);
      applyUpdate(updated);
      return updated;
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
      return null;
    }
  };

  const updateProperty = data =>
    runUpdate('tickets/updateTicket', { id: ticketId.value, ...data });

  // Stage changes go through `move`; `update` strips ticket_column_id. Position
  // is deliberately omitted so the server slots the ticket in by ticket number.
  const moveToColumn = ticketColumnId =>
    runUpdate('tickets/moveTicket', { id: ticketId.value, ticketColumnId });

  // Status has no generic setter: the model's resolve!/reopen!/close! are what
  // write resolved_at/closed_at and the matching activity.
  const STATUS_ACTIONS = {
    open: 'tickets/reopenTicket',
    resolved: 'tickets/resolveTicket',
    closed: 'tickets/closeTicket',
  };

  const changeStatus = status => {
    const action = STATUS_ACTIONS[status];
    if (!action) return Promise.resolve(null);
    return runUpdate(action, ticketId.value);
  };

  watch(
    ticketId,
    async () => {
      const loaded = await loadTicket();
      loadMesaContext(loaded?.team_id);
    },
    { immediate: true }
  );

  return {
    ticket,
    isLoading,
    canUpdate,
    columns,
    mesaAgents,
    updateProperty,
    moveToColumn,
    changeStatus,
    reload: loadTicket,
  };
}
