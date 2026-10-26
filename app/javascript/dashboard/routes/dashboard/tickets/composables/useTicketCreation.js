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
    // Modulo de Desenvolvimento - so' aparecem/valem quando `isDevMesa` e'
    // verdadeiro; em qualquer outra Mesa ficam `null`/vazios e nunca chegam
    // ao payload por conta propria (`toPayload` abaixo decide).
    // Vem do contexto quando o ticket nasce de dentro de um Sprint (tela de
    // Sprint ativo) - nulo (Backlog) em qualquer outra origem.
    sprintId: null,
    developmentType: null,
    devFeature: '',
    devRetrabalho: false,
    devResolucao: null,
    devDetalhesOcultos: '',
    devEstimativaHoras: null,
    devTempoTesteHoras: null,
    devDataLimite: '',
    devFeitoTriagem: false,
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

  // Sprints nao-concluidos da Mesa - so' usados quando `isDevMesa`, mas a
  // lista e' buscada do mesmo jeito que Categorias/Complexidade, sem
  // condicional: uma Mesa sem o modulo simplesmente nunca tem nenhum.
  const sprints = computed(
    () => store.getters['ticketColumns/getSprints'](form.value.teamId) || []
  );

  // Se a Mesa deste ticket usa niveis de responsavel. Vem da Mesa, e nao de
  // nenhum estado proprio: e configuracao dela, a mesma fonte que
  // `useTicketDetail.js` ja le para a tela de detalhe.
  const usesAssigneeLevels = computed(
    () =>
      store.getters['teams/getTeam'](form.value.teamId)
        ?.assignee_levels_enabled === true
  );

  // Quais niveis esta Mesa usa. O SERVIDOR sempre devolve ao menos o Nivel 1
  // (`Team#assignee_levels`, mesmo com a configuracao desligada) - por isso
  // esta lista nunca e' vazia, e nao e' ela que diz se a Mesa usa niveis.
  // Quem diz isso e' `usesAssigneeLevels`, acima.
  const assigneeLevels = computed(
    () =>
      store.getters['teams/getTeam'](form.value.teamId)?.assignee_levels || []
  );

  // So' essa Mesa (configurada pelo admin, nunca por nome) ganha os campos do
  // Modulo de Desenvolvimento no formulario.
  const isDevMesa = computed(
    () =>
      store.getters['teams/getTeam'](form.value.teamId)
        ?.development_module_enabled === true
  );

  // Quem pode ser responsavel de um nivel. Mesma regra do
  // `Team#members_for_level` no servidor: sem a configuracao ligada nao ha
  // niveis, e todo MEMBRO DA MESA serve - filtrar por `member.levels` aqui
  // devolvia lista vazia para toda Mesa que nunca usou niveis, porque nenhum
  // membro dela jamais teve nivel nenhum cadastrado. Era por isso que a Mesa
  // de Implantacao (niveis desligados) nao deixava informar o responsavel.
  const membersForLevel = level => {
    if (!usesAssigneeLevels.value) return mesaMembers.value;

    return mesaMembers.value.filter(member =>
      (member.levels || []).includes(level)
    );
  };

  const loadMesaContext = teamId => {
    if (!teamId) return;
    store.dispatch('ticketColumns/fetchColumns', teamId);
    store.dispatch('ticketColumns/fetchCategories', teamId);
    store.dispatch('ticketColumns/fetchSprints', teamId);
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
      sprintId: source.sprintId ?? null,
      developmentType: null,
      devFeature: '',
      devRetrabalho: false,
      devResolucao: null,
      devDetalhesOcultos: '',
      devEstimativaHoras: null,
      devTempoTesteHoras: null,
      devDataLimite: '',
      devFeitoTriagem: false,
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
      // Os campos do Modulo de Desenvolvimento nao valem fora de uma Mesa com
      // o modulo ligado - trocar de Mesa descarta qualquer valor deles. O
      // Sprint tambem e' de uma Mesa so' - o de uma Mesa anterior nunca serve
      // para a nova.
      form.value.sprintId = null;
      form.value.developmentType = null;
      form.value.devFeature = '';
      form.value.devRetrabalho = false;
      form.value.devResolucao = null;
      form.value.devDetalhesOcultos = '';
      form.value.devEstimativaHoras = null;
      form.value.devTempoTesteHoras = null;
      form.value.devDataLimite = '';
      form.value.devFeitoTriagem = false;
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

  // Lista separada por virgula -> array, descartando espacos e itens vazios -
  // o jeito mais simples de digitar uma lista curta sem montar um seletor novo.
  const toList = text =>
    String(text || '')
      .split(',')
      .map(item => item.trim())
      .filter(Boolean);

  // Vazio em branco no formulario nunca grava string vazia/zero no jsonb -
  // fica de fora da chave, que e' o mesmo que "sem valor" pra quem le depois.
  const devCustomAttributes = () => {
    const attrs = {};
    if (form.value.devFeature) attrs.feature = toList(form.value.devFeature);
    attrs.retrabalho = form.value.devRetrabalho;
    if (form.value.devResolucao) attrs.resolucao = form.value.devResolucao;
    if (form.value.devDetalhesOcultos) {
      attrs.detalhes_ocultos = toList(form.value.devDetalhesOcultos);
    }
    if (form.value.devEstimativaHoras) {
      attrs.estimativa_original_horas = Number(form.value.devEstimativaHoras);
    }
    if (form.value.devTempoTesteHoras) {
      attrs.tempo_teste_horas = Number(form.value.devTempoTesteHoras);
    }
    if (form.value.devDataLimite) attrs.data_limite = form.value.devDataLimite;
    attrs.feito_triagem = form.value.devFeitoTriagem;
    return attrs;
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
    // So' uma Mesa com o Modulo de Desenvolvimento ligado manda esses dois -
    // nas demais eles nem aparecem no payload, exatamente como hoje.
    ...(isDevMesa.value
      ? {
          sprint_id: form.value.sprintId || null,
          development_type: form.value.developmentType || null,
          custom_attributes: devCustomAttributes(),
        }
      : {}),
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
      developmentType: null,
      devFeature: '',
      devRetrabalho: false,
      devResolucao: null,
      devDetalhesOcultos: '',
      devEstimativaHoras: null,
      devTempoTesteHoras: null,
      devDataLimite: '',
      devFeitoTriagem: false,
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
    sprints,
    usesAssigneeLevels,
    assigneeLevels,
    membersForLevel,
    requiresAttachment,
    isDevMesa,
    isValid,
    toPayload,
    resetForNext,
  };
}
