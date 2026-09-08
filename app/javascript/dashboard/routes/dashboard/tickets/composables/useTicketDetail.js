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

  // TicketPolicy#add_sla_hours? is admin or assignee - stricter than update?,
  // so the SLA entry cannot be derived from `canUpdate`.
  const canAddSlaHours = computed(() => !!ticket.value?.can_add_sla_hours);

  // Estagios of the ticket's own Mesa. Fetched through the lean columns index -
  // pulling the Kanban board just to populate a select costs the whole payload.
  const columns = computed(
    () => store.getters['ticketColumns/getColumns'](ticket.value?.team_id) || []
  );

  // Categories of this ticket's Mesa, the same rule the stages follow.
  const categories = computed(
    () =>
      store.getters['ticketColumns/getCategories'](ticket.value?.team_id) || []
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
    store.dispatch('ticketColumns/fetchCategories', teamId);
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
    cancelled: 'tickets/cancelTicket',
  };

  const changeStatus = status => {
    const action = STATUS_ACTIONS[status];
    if (!action) return Promise.resolve(null);
    // `cancelTicket` carries an optional reason, so it takes an object where
    // the other three take a bare id.
    const payload =
      status === 'cancelled' ? { id: ticketId.value } : ticketId.value;
    return runUpdate(action, payload);
  };

  // Every composite action returns the affected ticket's full detail payload and
  // funnels through `runUpdate`, so the Kanban, the counters and the Historico
  // all follow from one place.
  const transfer = attributes =>
    runUpdate('tickets/transferTicket', { id: ticketId.value, ...attributes });

  const setParent = parentId =>
    runUpdate('tickets/setTicketParent', { id: ticketId.value, parentId });

  const merge = sourceId =>
    runUpdate('tickets/mergeTicket', { id: ticketId.value, sourceId });

  const assignToMe = () =>
    runUpdate('tickets/assignTicketToMe', ticketId.value);

  const adjustSla = ({ hours, dueAt, reason, slaKind }) =>
    runUpdate('tickets/adjustTicketSla', {
      id: ticketId.value,
      hours,
      dueAt,
      reason,
      slaKind,
    });

  const cancel = reason =>
    runUpdate('tickets/cancelTicket', { id: ticketId.value, reason });

  // These two return a DIFFERENT ticket than the one in view, so they do not go
  // through `runUpdate` (which refreshes this ticket's history): the caller
  // navigates to the new ticket instead.
  const createChild = async ({ options, ticket: attributes }) => {
    try {
      const child = await store.dispatch('tickets/createChildTicket', {
        id: ticketId.value,
        options,
        ticket: attributes,
      });
      store.dispatch('ticketColumns/applyRealtimeTicket', child);
      return child;
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
      return null;
    }
  };

  const duplicate = async () => {
    try {
      const copy = await store.dispatch(
        'tickets/duplicateTicket',
        ticketId.value
      );
      store.dispatch('ticketColumns/applyRealtimeTicket', copy);
      return copy;
    } catch (error) {
      useAlert(t('TICKET.API.ERROR_MESSAGE'));
      return null;
    }
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
    canAddSlaHours,
    columns,
    categories,
    mesaAgents,
    updateProperty,
    moveToColumn,
    changeStatus,
    transfer,
    createChild,
    setParent,
    merge,
    duplicate,
    assignToMe,
    adjustSla,
    cancel,
    reload: loadTicket,
  };
}
