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
    branches: ['no_companies'],
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
// Categoria, Assistente) e este monta o resto - a mesma sequencia descrita
// no guia de configuracao. Substitui totalmente as etapas atuais.
export const buildWhatsappTriageTemplate = ({
  teamId,
  ticketColumnId,
  ticketCategoryId,
  assistantId,
  level3to5TeamId,
}) => [
  {
    id: 's1',
    type: 'send_message',
    params: {
      content: 'Olá! Vou localizar seu cadastro e verificar seu atendimento.',
    },
    next: 's2',
    branches: {},
  },
  // Identifica o cliente (a Empresa) primeiro - antes de perguntar qualquer
  // outra coisa, inclusive se ja existe um ticket aberto. Contato sem
  // nenhuma empresa ainda (cliente novo) cai no ramo `no_companies`, que
  // pede o CNPJ (s15-s17) antes de voltar para o fluxo principal em s3.
  {
    id: 's2',
    type: 'list_companies',
    params: { save_as: 'resposta.empresa_escolhida' },
    next: 's3',
    branches: { no_companies: 's15' },
  },
  {
    id: 's3',
    type: 'check_company_blocked',
    params: {},
    next: 's5',
    branches: { blocked: 's4' },
  },
  {
    id: 's4',
    type: 'handoff',
    params: {
      content:
        'Não conseguimos continuar esse atendimento por aqui. Vou te transferir para um atendente.',
      reason: 'empresa_bloqueada',
    },
    next: null,
    branches: {},
  },
  {
    id: 's5',
    type: 'ask',
    params: {
      content:
        'Você já possui um ticket aberto para esse atendimento? Responda sim ou não.',
      save_as: 'resposta.tem_ticket',
      answer_type: 'text',
    },
    next: 's6',
    branches: {},
  },
  {
    id: 's6',
    type: 'condition',
    params: {
      variable: 'resposta.tem_ticket',
      operator: 'contains',
      value: 'sim',
    },
    next: null,
    branches: { true: 's7', false: 's10' },
  },
  {
    id: 's7',
    type: 'ask',
    params: {
      content: 'Certo, me informe o número do ticket.',
      save_as: 'resposta.numero_ticket',
      answer_type: 'ticket_number',
      retry_message: 'Não consegui reconhecer esse número. Pode enviar de novo?',
    },
    next: 's8',
    branches: {},
  },
  {
    id: 's8',
    type: 'find_open_ticket_by_number',
    params: { number_from: 'resposta.numero_ticket' },
    next: 's9',
    branches: { not_found: 's10', not_owned: 's10' },
  },
  {
    id: 's9',
    type: 'send_message',
    params: {
      content: 'Encontrei o seu ticket #{{ticket.numero}}! Vou continuar por aqui.',
    },
    next: null,
    branches: {},
  },
  {
    id: 's10',
    type: 'find_open_ticket_for_customer',
    params: { team_id: teamId },
    next: 's11',
    branches: { found: 's12' },
  },
  {
    id: 's11',
    type: 'create_ticket',
    params: {
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático de WhatsApp.',
      team_id: teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
      priority: 'medium',
    },
    next: 's12',
    branches: {},
  },
  {
    id: 's12',
    type: 'condition',
    params: {
      variable: 'empresa.nivel',
      operator: 'greater_than_or_equal',
      value: '3',
    },
    next: null,
    branches: { true: 's14', false: 's13' },
  },
  {
    id: 's13',
    type: 'ai_resolve',
    params: { assistant_id: assistantId, max_turns: 6 },
    next: null,
    branches: {},
  },
  {
    id: 's14',
    type: 'ai_triage',
    params: { team_id: level3to5TeamId || '' },
    next: null,
    branches: {},
  },
  // Cliente novo, sem nenhuma empresa vinculada ainda: pede o CNPJ e localiza
  // a empresa por ele antes de voltar ao fluxo principal (s3, checar bloqueio).
  {
    id: 's15',
    type: 'ask',
    params: {
      content:
        'Não encontrei nenhuma empresa vinculada ao seu contato. Pode me informar o CNPJ da empresa?',
      save_as: 'resposta.cnpj',
      answer_type: 'cnpj',
      retry_message: 'Esse CNPJ não parece válido. Pode conferir e enviar de novo?',
    },
    next: 's16',
    branches: {},
  },
  {
    id: 's16',
    type: 'find_company',
    params: { cnpj_from: 'resposta.cnpj' },
    next: 's3',
    branches: { not_found: 's17' },
  },
  {
    id: 's17',
    type: 'handoff',
    params: {
      content:
        'Não localizamos essa empresa em nosso cadastro. Vou transferir você para um atendente.',
      reason: 'empresa_nao_encontrada',
    },
    next: null,
    branches: {},
  },
];

// O modelo pronto de triagem do Widget: sem telefone para identificar o
// cliente automaticamente, a ordem se inverte em relacao ao WhatsApp - CNPJ
// primeiro, depois nome/e-mail (reaproveitados se o Widget/pre-chat ja
// souber), so entao nivel e ticket. O ticket so e criado no final (a etapa
// `ai_resolve` cria sozinha quando resolve ou encaminha; a `create_ticket`
// antes da `ai_triage` documenta a triagem assim que ela comeca).
export const buildWidgetTriageTemplate = ({
  teamId,
  ticketColumnId,
  ticketCategoryId,
  assistantId,
  level3to5TeamId,
}) => [
  {
    id: 's1',
    type: 'ask',
    params: {
      content:
        'Olá! Para começarmos, preciso identificar a empresa que você representa. Informe o CNPJ da empresa.',
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
    next: 's4',
    branches: { not_found: 's3' },
  },
  {
    id: 's3',
    type: 'handoff',
    params: {
      content: 'Não encontrei o CNPJ informado entre nossos clientes.',
      reason: 'cnpj_nao_encontrado',
    },
    next: null,
    branches: {},
  },
  {
    id: 's4',
    type: 'check_company_blocked',
    params: {},
    next: 's6',
    branches: { blocked: 's5' },
  },
  {
    id: 's5',
    type: 'handoff',
    params: {
      content:
        'Não conseguimos continuar esse atendimento por aqui. Vou te transferir para um atendente.',
      reason: 'empresa_bloqueada',
    },
    next: null,
    branches: {},
  },
  // Nome e e-mail: so pergunta o que o Widget/pre-chat ainda nao sabe.
  {
    id: 's6',
    type: 'condition',
    params: { variable: 'contato.nome', operator: 'is_present' },
    next: null,
    branches: { true: 's8', false: 's7' },
  },
  {
    id: 's7',
    type: 'ask',
    params: {
      content:
        'Agora preciso de algumas informações para identificar você. Qual é o seu nome?',
      save_as: 'resposta.nome',
      answer_type: 'text',
    },
    next: 's8',
    branches: {},
  },
  {
    id: 's8',
    type: 'condition',
    params: { variable: 'contato.email', operator: 'is_present' },
    next: null,
    branches: { true: 's10', false: 's9' },
  },
  {
    id: 's9',
    type: 'ask',
    params: {
      content: 'Qual é o seu e-mail?',
      save_as: 'resposta.email',
      answer_type: 'text',
    },
    next: 's10',
    branches: {},
  },
  {
    id: 's10',
    type: 'link_contact_to_company',
    params: {},
    next: 's12',
    branches: { inconsistent: 's11' },
  },
  {
    id: 's11',
    type: 'handoff',
    params: {
      content:
        'Para continuar, preciso confirmar alguns dados com um de nossos atendentes.',
      reason: 'informacoes_inconsistentes',
    },
    next: null,
    branches: {},
  },
  {
    id: 's12',
    type: 'ask',
    params: {
      content: 'Você já possui um ticket aberto para esse atendimento?',
      save_as: 'resposta.tem_ticket',
      answer_type: 'text',
    },
    next: 's13',
    branches: {},
  },
  {
    id: 's13',
    type: 'condition',
    params: {
      variable: 'resposta.tem_ticket',
      operator: 'contains',
      value: 'sim',
    },
    next: null,
    branches: { true: 's14', false: 's18' },
  },
  {
    id: 's14',
    type: 'ask',
    params: {
      content:
        'Certo. Informe o número do ticket para que eu possa localizar seu atendimento.',
      save_as: 'resposta.numero_ticket',
      answer_type: 'ticket_number',
      retry_message: 'Não consegui reconhecer esse número. Pode enviar de novo?',
    },
    next: 's15',
    branches: {},
  },
  {
    id: 's15',
    type: 'find_open_ticket_by_number',
    params: { number_from: 'resposta.numero_ticket' },
    next: 's17',
    branches: { not_found: 's16', not_owned: 's16' },
  },
  {
    id: 's16',
    type: 'send_message',
    params: { content: 'Não consegui localizar o ticket informado.' },
    next: 's18',
    branches: {},
  },
  {
    id: 's17',
    type: 'handoff',
    params: {
      content:
        'Perfeito! Localizei o ticket #{{ticket.numero}}. Vou encaminhar seu atendimento para a equipe responsável dar continuidade.',
      reason: 'ticket_existente',
    },
    next: null,
    branches: {},
  },
  // Sem ticket (ou informado nao encontrado): segue por nivel. O ticket so
  // e criado no final de cada caminho, nunca aqui.
  {
    id: 's18',
    type: 'condition',
    params: {
      variable: 'empresa.nivel',
      operator: 'greater_than_or_equal',
      value: '3',
    },
    next: null,
    branches: { true: 's20', false: 's19' },
  },
  {
    id: 's19',
    type: 'ai_resolve',
    params: {
      assistant_id: assistantId,
      max_turns: 6,
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático do Widget.',
      team_id: teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
    },
    next: null,
    branches: {},
  },
  {
    id: 's20',
    type: 'create_ticket',
    params: {
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático do Widget.',
      team_id: teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
      priority: 'medium',
    },
    next: 's21',
    branches: {},
  },
  {
    id: 's21',
    type: 'ai_triage',
    params: { team_id: level3to5TeamId || '' },
    next: null,
    branches: {},
  },
];
