import { computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';

// The state behind the single creation form, shared by all three entry points
// (Kanban, Conversation, child ticket). The form component stays a layout.
//
// The dependency chain is the whole point: the Mesa decides which Estagios,
// Categories and members exist, and the Empresa decides which Contacts do.
// Whenever one changes, whatever depended on it is reloaded and any now-invalid
// choice is dropped - the backend rejects those pairs, so keeping them would
// only turn into a failed save.
export function useTicketCreation(context) {
  const store = useStore();

  const form = ref({
    companyId: null,
    contactId: null,
    teamId: null,
    ticketColumnId: null,
    ticketCategoryId: null,
    priority: 'medium',
    assigneeId: null,
    title: '',
    description: '',
    followerIds: [],
    parentId: null,
  });

  const files = ref([]);
  const teams = useMapGetter('teams/getTeams');

  const columns = computed(
    () => store.getters['ticketColumns/getColumns'](form.value.teamId) || []
  );
  const categories = computed(
    () => store.getters['ticketColumns/getCategories'](form.value.teamId) || []
  );
  const mesaMembers = computed(
    () => store.getters['teamMembers/getTeamMembers'](form.value.teamId) || []
  );

  const loadMesaContext = teamId => {
    if (!teamId) return;
    store.dispatch('ticketColumns/fetchColumns', teamId);
    store.dispatch('ticketColumns/fetchCategories', teamId);
    store.dispatch('teamMembers/get', { teamId });
  };

  // The context a caller already knows: Mesa/Estagio from the Kanban column,
  // Empresa/Solicitante/Conversation from a chat, everything from the parent
  // when opening a child.
  const applyContext = () => {
    const source = context.value || {};
    form.value = {
      ...form.value,
      companyId: source.companyId ?? null,
      contactId: source.contactId ?? null,
      teamId: source.teamId ?? null,
      ticketColumnId: source.ticketColumnId ?? null,
      ticketCategoryId: source.ticketCategoryId ?? null,
      priority: source.priority ?? 'medium',
      assigneeId: source.assigneeId ?? null,
      title: source.title ?? '',
      description: source.description ?? '',
      followerIds: source.followerIds ?? [],
      parentId: source.parentId ?? null,
    };
    files.value = [];
    loadMesaContext(form.value.teamId);
  };

  // A ticket cannot exist without an Estagio, so the Mesa's first one is a
  // better default than an empty select.
  const defaultColumn = () => {
    if (!form.value.ticketColumnId && columns.value.length) {
      form.value.ticketColumnId = columns.value[0].id;
    }
  };

  // Switching Mesa invalidates the Estagio, the Category and the Responsavel.
  watch(
    () => form.value.teamId,
    (teamId, previous) => {
      loadMesaContext(teamId);
      if (previous == null || teamId === previous) return;
      form.value.ticketColumnId = null;
      form.value.ticketCategoryId = null;
      form.value.assigneeId = null;
      form.value.followerIds = [];
      // Applied here rather than left to the `columns` watcher below: when the
      // new Mesa's list is already cached both run in the same tick, and the
      // clearing above would land last.
      defaultColumn();
    }
  );

  // Covers the list arriving from the server after the Mesa was chosen.
  watch(columns, defaultColumn);

  // The Solicitante belongs to the Empresa; TicketContactSelect clears itself
  // when the Empresa changes, and this keeps the form in step.
  watch(
    () => form.value.companyId,
    (companyId, previous) => {
      if (previous === undefined || companyId === previous) return;
      form.value.contactId = null;
    }
  );

  const REQUIRED = [
    'companyId',
    'contactId',
    'teamId',
    'ticketColumnId',
    'ticketCategoryId',
    'priority',
  ];

  // A Categoria escolhida pode exigir anexo. A regra vem do cadastro dela - a
  // mesma que a Area do Cliente respeita -, e nao de uma lista aqui.
  const selectedCategory = computed(() =>
    categories.value.find(c => c.id === form.value.ticketCategoryId)
  );

  const requiresAttachment = computed(() =>
    Boolean(selectedCategory.value?.require_attachment)
  );

  const isValid = computed(
    () =>
      REQUIRED.every(field => !!form.value[field]) &&
      form.value.title.trim().length > 0 &&
      form.value.description.trim().length > 0 &&
      (!requiresAttachment.value || files.value.length > 0)
  );

  // Snake case, because this is what the tickets endpoint expects.
  const toPayload = () => ({
    title: form.value.title.trim(),
    description: form.value.description,
    priority: form.value.priority,
    company_id: form.value.companyId,
    contact_id: form.value.contactId,
    team_id: form.value.teamId,
    ticket_column_id: form.value.ticketColumnId,
    ticket_category_id: form.value.ticketCategoryId,
    assignee_id: form.value.assigneeId || null,
    follower_ids: form.value.followerIds,
    parent_id: form.value.parentId || null,
  });

  // "Criar e abrir outro" keeps the context the agent would otherwise retype -
  // the Empresa, the Solicitante and where the ticket lands - and clears what
  // describes this particular ticket.
  const resetForNext = () => {
    form.value = {
      ...form.value,
      title: '',
      description: '',
      ticketCategoryId: null,
      followerIds: [],
      parentId: null,
    };
    files.value = [];
  };

  watch(context, applyContext, { immediate: true, deep: true });

  return {
    form,
    files,
    teams,
    columns,
    categories,
    mesaMembers,
    requiresAttachment,
    isValid,
    toPayload,
    resetForNext,
  };
}
