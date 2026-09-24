// O que cada tipo de etapa pede para ser configurado.
//
// Esta tabela e o unico lugar que o editor consulta: um tipo novo aparece na
// tela inteira - seletor, campos e ramos - so de ser acrescentado aqui. Os
// nomes dos tipos e dos campos sao os mesmos que o runner do backend le, entao
// nada precisa ser traduzido entre as duas pontas.
//
// `field.kind` diz como desenhar: text, textarea, number, select ou variable.
// `branches` sao as saidas alem da proxima etapa - os caminhos do "e se nao?".

export const FLOW_STEP_TYPES = [
  {
    type: 'send_message',
    fields: [{ key: 'content', kind: 'textarea', required: true }],
  },
  {
    type: 'ask',
    fields: [
      { key: 'content', kind: 'textarea', required: true },
      { key: 'save_as', kind: 'text', required: true, placeholder: 'nome' },
      {
        key: 'answer_type',
        kind: 'select',
        options: ['text', 'cnpj', 'ticket_number'],
        default: 'text',
      },
      { key: 'retry_message', kind: 'text' },
      { key: 'timeout_minutes', kind: 'number', default: 60 },
    ],
  },
  {
    type: 'find_company',
    fields: [{ key: 'cnpj_from', kind: 'variable', default: 'resposta.cnpj' }],
    branches: ['not_found'],
  },
  {
    type: 'find_contact',
    fields: [{ key: 'name_from', kind: 'variable', default: 'resposta.nome' }],
    branches: ['not_found'],
  },
  {
    type: 'condition',
    fields: [
      { key: 'variable', kind: 'variable', required: true },
      {
        key: 'operator',
        kind: 'select',
        default: 'equal_to',
        options: [
          'equal_to',
          'not_equal_to',
          'contains',
          'does_not_contain',
          'is_present',
          'is_not_present',
          'greater_than_or_equal',
          'less_than_or_equal',
        ],
      },
      { key: 'value', kind: 'text' },
    ],
    branches: ['true', 'false'],
  },
  {
    type: 'create_ticket',
    fields: [
      { key: 'title', kind: 'text', required: true },
      { key: 'description', kind: 'textarea' },
      { key: 'team_id', kind: 'select', source: 'teams', required: true },
      { key: 'ticket_column_id', kind: 'select', source: 'columns' },
      { key: 'ticket_category_id', kind: 'select', source: 'categories' },
      {
        key: 'priority',
        kind: 'select',
        default: 'medium',
        options: ['low', 'medium', 'high', 'urgent'],
      },
    ],
  },
  {
    type: 'handoff',
    fields: [{ key: 'content', kind: 'textarea' }],
  },
  {
    type: 'check_company_blocked',
    fields: [],
    branches: ['blocked'],
  },
  {
    type: 'find_open_ticket_by_number',
    fields: [
      { key: 'number_from', kind: 'variable', default: 'resposta.numero_ticket' },
    ],
    branches: ['not_found', 'not_owned'],
  },
  {
    type: 'find_open_ticket_for_customer',
    fields: [{ key: 'team_id', kind: 'select', source: 'teams', required: true }],
    branches: ['found'],
  },
  {
    type: 'list_companies',
    fields: [{ key: 'save_as', kind: 'text', default: 'resposta.empresa_escolhida' }],
    branches: ['no_companies', 'not_selected'],
  },
  {
    type: 'ai_resolve',
    fields: [
      { key: 'assistant_id', kind: 'select', source: 'captainAssistants', required: true },
      { key: 'max_turns', kind: 'number', default: 6 },
      // So usados se nenhum `create_ticket` rodou antes desta etapa - o
      // ticket entao e criado so no final (resolvido ou encaminhado).
      { key: 'title', kind: 'text' },
      { key: 'description', kind: 'textarea' },
      { key: 'team_id', kind: 'select', source: 'teams' },
      { key: 'ticket_column_id', kind: 'select', source: 'columns' },
      { key: 'ticket_category_id', kind: 'select', source: 'categories' },
    ],
    // Sem `branches`: esta etapa sempre termina sozinha (a IA resolve e o
    // fluxo para, ou aciona handoff) - nunca segue para uma proxima etapa.
  },
  {
    type: 'ai_triage',
    fields: [
      { key: 'team_id', kind: 'select', source: 'teams', required: true },
      { key: 'content', kind: 'textarea' },
    ],
    // Idem: termina sempre em handoff, nunca em `next`.
  },
  {
    type: 'link_contact_to_company',
    fields: [],
    branches: ['inconsistent'],
  },
];

export const findStepType = type =>
  FLOW_STEP_TYPES.find(definition => definition.type === type);

// As variaveis que o fluxo oferece. As de `resposta.` dependem do que cada
// etapa `ask` guardou, entao sao lidas do proprio fluxo em vez de listadas fixo.
export const BASE_VARIABLES = [
  'empresa.nome',
  'empresa.cnpj',
  'empresa.id',
  'empresa.nivel',
  'contato.nome',
  'contato.email',
  'contato.id',
  'ticket.numero',
  'ticket.titulo',
  'ticket.id',
];

export const variablesFor = (steps = []) => {
  const answers = steps
    .filter(step => step.type === 'ask' && step.params?.save_as)
    .map(step => `resposta.${step.params.save_as.replace(/^resposta\./, '')}`);

  return [...new Set([...answers, ...BASE_VARIABLES])];
};

// Ids curtos e estaveis: o `next` de uma etapa aponta para o id de outra, entao
// renumerar ao remover quebraria as ligacoes de quem apontava para ela.
export const nextStepId = (steps = []) => {
  const used = steps.map(
    step => Number((step.id || '').replace(/\D/g, '')) || 0
  );
  return `s${Math.max(0, ...used) + 1}`;
};

export const buildStep = (type, steps) => {
  const definition = findStepType(type);
  const params = {};
  (definition?.fields || []).forEach(field => {
    if (field.default !== undefined) params[field.key] = field.default;
  });

  return { id: nextStepId(steps), type, params, next: null, branches: {} };
};

// O modelo pronto de triagem de WhatsApp: em vez de montar cada etapa a mao,
// o admin escolhe so o que e realmente uma decisao dele (Mesa, Estagio,
// Categoria) e este monta o resto. Triagem rapida e objetiva (pedido da
// Ingrid, revisao completa do fluxo): so CNPJ, confere habilitacao, pergunta
// o problema, classifica e encaminha - sem "ja tem ticket aberto?" nem
// nenhuma outra pergunta alem do minimo necessario. A IA nunca tenta
// resolver, so classifica e encaminha pra humano.
export const buildWhatsappTriageTemplate = ({
  teamId,
  ticketColumnId,
  ticketCategoryId,
  triageTeamId,
}) => [
  {
    id: 's1',
    type: 'ask',
    params: {
      content:
        'Olá! Você está no atendimento da Duesoft.\n\nPara começarmos, me informe o CNPJ da empresa.',
      save_as: 'resposta.cnpj',
      answer_type: 'cnpj',
      retry_message: 'Esse CNPJ não parece válido. Pode conferir e enviar de novo?',
    },
    next: 's2',
    branches: {},
  },
  {
    id: 's2',
    type: 'find_company',
    params: { cnpj_from: 'resposta.cnpj' },
    next: 's3',
    branches: { not_found: 's6' },
  },
  {
    id: 's3',
    type: 'check_company_blocked',
    params: {},
    next: 's4',
    branches: { blocked: 's5' },
  },
  {
    id: 's4',
    type: 'ask',
    params: {
      content:
        'Perfeito! Encontrei o CNPJ {{empresa.cnpj}} vinculado à empresa *{{empresa.nome}}*.\n\nO que está acontecendo?',
      save_as: 'resposta.problema',
      answer_type: 'text',
    },
    next: 's7',
    branches: {},
  },
  {
    id: 's5',
    type: 'handoff',
    params: {
      content:
        'No momento, a empresa *{{empresa.nome}}* não está habilitada para atendimento por este canal.\n\nPara verificar a situação e obter orientações, entre em contato conosco pelo telefone {{conta.telefone_suporte}}.',
      reason: 'empresa_bloqueada',
    },
    next: null,
    branches: {},
  },
  {
    id: 's6',
    type: 'handoff',
    params: {
      content:
        'Não localizei esse CNPJ em nossa base.\n\nVou encaminhar você para o atendimento para que nossa equipe possa verificar.',
      reason: 'cnpj_nao_encontrado',
    },
    next: null,
    branches: {},
  },
  {
    id: 's7',
    type: 'create_ticket',
    params: {
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático de WhatsApp.',
      team_id: triageTeamId || teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
      priority: 'medium',
    },
    next: 's8',
    branches: {},
  },
  {
    id: 's8',
    type: 'ai_triage',
    params: { team_id: triageTeamId || '' },
    next: null,
    branches: {},
  },
];

// O modelo pronto de triagem do Widget: mesma espinha dorsal do WhatsApp
// (CNPJ - habilitacao - problema - classificacao - fila), so que aqui, sem
// telefone pra identificar quem esta escrevendo, ainda pergunta nome/e-mail
// (so o que o pre-chat do Widget nao trouxer) antes da pergunta do problema.
export const buildWidgetTriageTemplate = ({
  teamId,
  ticketColumnId,
  ticketCategoryId,
  triageTeamId,
}) => [
  {
    id: 's1',
    type: 'ask',
    params: {
      content:
        'Olá! Você está no atendimento da Duesoft.\n\nPara começarmos, me informe o CNPJ da empresa.',
      save_as: 'resposta.cnpj',
      answer_type: 'cnpj',
      retry_message: 'Esse CNPJ não parece válido. Pode conferir e enviar de novo?',
    },
    next: 's2',
    branches: {},
  },
  {
    id: 's2',
    type: 'find_company',
    params: { cnpj_from: 'resposta.cnpj' },
    next: 's3',
    branches: { not_found: 's12' },
  },
  {
    id: 's3',
    type: 'check_company_blocked',
    params: {},
    next: 's4',
    branches: { blocked: 's13' },
  },
  // Nome e e-mail: so pergunta o que o Widget/pre-chat ainda nao sabe.
  {
    id: 's4',
    type: 'condition',
    params: { variable: 'contato.nome', operator: 'is_present' },
    next: null,
    branches: { true: 's6', false: 's5' },
  },
  {
    id: 's5',
    type: 'ask',
    params: {
      content:
        'Agora preciso de algumas informações para identificar você. Qual é o seu nome?',
      save_as: 'resposta.nome',
      answer_type: 'text',
    },
    next: 's6',
    branches: {},
  },
  {
    id: 's6',
    type: 'condition',
    params: { variable: 'contato.email', operator: 'is_present' },
    next: null,
    branches: { true: 's8', false: 's7' },
  },
  {
    id: 's7',
    type: 'ask',
    params: {
      content: 'Qual é o seu e-mail?',
      save_as: 'resposta.email',
      answer_type: 'text',
    },
    next: 's8',
    branches: {},
  },
  {
    id: 's8',
    type: 'link_contact_to_company',
    params: {},
    next: 's9',
    branches: { inconsistent: 's14' },
  },
  {
    id: 's9',
    type: 'ask',
    params: {
      content:
        'Perfeito! Encontrei o CNPJ {{empresa.cnpj}} vinculado à empresa *{{empresa.nome}}*.\n\nO que está acontecendo?',
      save_as: 'resposta.problema',
      answer_type: 'text',
    },
    next: 's10',
    branches: {},
  },
  {
    id: 's10',
    type: 'create_ticket',
    params: {
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático do Widget.',
      team_id: triageTeamId || teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
      priority: 'medium',
    },
    next: 's11',
    branches: {},
  },
  {
    id: 's11',
    type: 'ai_triage',
    params: { team_id: triageTeamId || '' },
    next: null,
    branches: {},
  },
  {
    id: 's12',
    type: 'handoff',
    params: {
      content:
        'Não localizei esse CNPJ em nossa base.\n\nVou encaminhar você para o atendimento para que nossa equipe possa verificar.',
      reason: 'cnpj_nao_encontrado',
    },
    next: null,
    branches: {},
  },
  {
    id: 's13',
    type: 'handoff',
    params: {
      content:
        'No momento, a empresa *{{empresa.nome}}* não está habilitada para atendimento por este canal.\n\nPara verificar a situação e obter orientações, entre em contato conosco pelo telefone {{conta.telefone_suporte}}.',
      reason: 'empresa_bloqueada',
    },
    next: null,
    branches: {},
  },
  {
    id: 's14',
    type: 'handoff',
    params: {
      content:
        'Para continuar, preciso confirmar alguns dados com um de nossos atendentes.',
      reason: 'informacoes_inconsistentes',
    },
    next: null,
    branches: {},
  },
];
