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
    // Um responsavel por NIVEL, e nao um so. A Mesa decide quantos niveis
    // existem; a chave e o numero do nivel, e `1` e o responsavel de sempre.
    assignees: {},
    title: '',
    description: '',
    followerIds: [],
    parentId: null,
    // A Complexidade. Opcional ao abrir - a exigencia e no fechamento -, e
    // filtrada pela Mesa.
    ticketComplexityId: null,
  });

  const files = ref([]);
  const teams = useMapGetter('teams/getTeams');

  const columns = computed(
    () => store.getters['ticketColumns/getColumns'](form.value.teamId) || []
  );
  const categories = computed(
    () => store.getters['ticketColumns/getCategories'](form.value.teamId) || []
  );
  // So os niveis que ESTA Mesa oferece. A regra de disponibilidade e do servidor;
  // o getter apenas recorta a mesma lista, em vez de manter uma segunda versao
  // dela.
  const complexities = computed(
    () =>
      store.getters['ticketComplexities/getComplexitiesForTeam']?.(
        form.value.teamId
      ) || []
  );
  const mesaMembers = computed(
    () => store.getters['teamMembers/getTeamMembers'](form.value.teamId) || []
  );

  // Quais niveis esta Mesa usa. Vazio quando ela nao usa niveis - e ai a tela
  // mostra um campo de responsavel so, como sempre mostrou.
  const assigneeLevels = computed(
    () =>
      store.getters['teams/getTeam'](form.value.teamId)?.assignee_levels || []
  );

  // So quem esta habilitado NAQUELE nivel. Oferecer todo mundo era o que fazia
  // um agente de Nivel 2 cair no campo do Nivel 1 e o servidor recusar - e numa
  // Mesa sem ninguem no Nivel 1, nao havia escolha possivel.
  const membersForLevel = level =>
    mesaMembers.value.filter(member => (member.levels || []).includes(level));

  const loadMesaContext = teamId => {
    if (!teamId) return;
    store.dispatch('ticketColumns/fetchColumns', teamId);
    store.dispatch('ticketColumns/fetchCategories', teamId);
    // A lista e da conta, entao uma leitura serve a todas as Mesas: o `fetch`
    // so acontece uma vez por visita.
    store.dispatch('ticketComplexities/fetch');
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
      ticketComplexityId: source.ticketComplexityId ?? null,
      priority: source.priority ?? 'medium',
      // Quem chama ainda entrega `assigneeId`: e o Nivel 1, que existe em
      // qualquer Mesa, com ou sem niveis configurados.
      assignees: source.assigneeId ? { 1: source.assigneeId } : {},
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
      // A Complexidade tambem: a Mesa nova pode nao oferecer o nivel escolhido, e
      // deixa-lo ali faria o servidor recusar a abertura com um campo que a tela
      // ja nao lista.
      form.value.ticketComplexityId = null;
      // Todos os niveis, e nao so o primeiro: quem respondia pela Mesa antiga
      // nao responde pela nova, em nivel nenhum.
      form.value.assignees = {};
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

  // Cada nivel na sua coluna. Niveis vazios vao como `null` de proposito: sem
  // isso, limpar um responsavel no formulario nao chegaria ao servidor.
  const assigneePayload = () => {
    const niveis = assigneeLevels.value.length ? assigneeLevels.value : [1];

    return niveis.reduce((acc, level) => {
      const campo = level === 1 ? 'assignee_id' : `assignee_${level}_id`;
      acc[campo] = form.value.assignees[level] || null;
      return acc;
    }, {});
  };

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
    // Vazio vira `null`, e nao string vazia: a coluna e uma chave estrangeira.
    ticket_complexity_id: form.value.ticketComplexityId || null,
    // `assignee_id` para o Nivel 1 e `assignee_N_id` para os demais - as
    // colunas que o servidor ja aceita (vide TicketActionParams).
    ...assigneePayload(),
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
    complexities,
    mesaMembers,
    assigneeLevels,
    membersForLevel,
    requiresAttachment,
    isValid,
    toPayload,
    resetForNext,
  };
}
