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
      content:
        'Olá, você está no canal de atendimento. Um momento enquanto busco suas informações.',
    },
    next: 's2',
    branches: {},
  },
  // Identifica o cliente (a Empresa) primeiro - antes de perguntar qualquer
  // outra coisa, inclusive se ja existe um ticket aberto. Contato sem
  // nenhuma empresa ainda (cliente novo), ou que recusa a(s) empresa(s)
  // apresentada(s), cai no CNPJ manual (s17-s20) antes de voltar ao fluxo
  // principal em s3.
  {
    id: 's2',
    type: 'list_companies',
    params: { save_as: 'resposta.empresa_escolhida' },
    next: 's3',
    branches: { no_companies: 's17', not_selected: 's17' },
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
    branches: { true: 's7', false: 's21' },
  },
  {
    id: 's7',
    type: 'ask',
    params: {
      content: 'Certo. Por favor, informe o número do ticket.',
      save_as: 'resposta.numero_ticket',
      answer_type: 'ticket_number',
      retry_message: 'Não consegui reconhecer esse número. Pode enviar de novo?',
    },
    next: 's8',
    branches: {},
  },
  // Ticket valido (10.1): vincula e encaminha IMEDIATAMENTE para humano - a
  // IA nunca continua tentando resolver quando ja existe um ticket aberto.
  // Nao encontrado (10.2) e de outro cliente/empresa (10.4) avisam o motivo
  // e seguem o fluxo normal (nao criam ticket aqui - so mais adiante, se
  // for o caso).
  {
    id: 's8',
    type: 'find_open_ticket_by_number',
    params: { number_from: 'resposta.numero_ticket' },
    next: 's11',
    branches: { not_found: 's9', not_owned: 's10' },
  },
  {
    id: 's9',
    type: 'send_message',
    params: { content: 'Não consegui localizar o ticket informado.' },
    next: 's21',
    branches: {},
  },
  {
    id: 's10',
    type: 'send_message',
    params: {
      content:
        'Esse ticket não pôde ser associado ao seu atendimento atual. Vou continuar normalmente.',
    },
    next: 's21',
    branches: {},
  },
  {
    id: 's11',
    type: 'handoff',
    params: {
      content:
        'Perfeito. Localizei o ticket #{{ticket.numero}}. Vou encaminhar seu atendimento para a equipe responsável dar continuidade.',
      reason: 'ticket_existente',
    },
    next: null,
    branches: {},
  },
  // Sem ticket aberto (11): sempre um atendimento novo - nao ha nenhuma
  // busca por ticket existente sem o cliente informar o numero (pedido
  // explicito: "quando e conversa nova, sempre um novo ticket"; dedup
  // automatico por contato+empresa+mesa reaproveitava tickets antigos de
  // teste mesmo para clientes diferentes, o que nao e' o comportamento
  // desejado). O ticket em si so e criado quando o caminho de nivel 3-5
  // exigir (s14) ou quando a IA de nivel 1-2 concluir (s16, sozinha).
  //
  // Antes de chamar a IA (nivel 1-2, s16) ou a triagem (nivel 3-5, s15), o
  // cliente ainda so respondeu perguntas de identificacao (empresa, ticket) -
  // nunca disse o que precisa. Sem uma pergunta explicita aqui, a IA de
  // resolucao recebia um historico sem nenhum problema declarado e, num
  // teste real, respondeu vazio (sem texto, sem chamar handoff de verdade) -
  // a rede de seguranca em `ai_resolve` acabava encaminhando so por nao ter
  // nada para responder, nao porque decidiu que devia. Perguntar aqui garante
  // que sempre existe uma descricao real do problema no historico antes da
  // IA (de qualquer nivel) entrar em acao.
  {
    id: 's21',
    type: 'ask',
    params: {
      content:
        'Certo! Agora me conta: o que está acontecendo? Pode descrever o problema com o máximo de detalhes possível.',
      save_as: 'resposta.problema',
      answer_type: 'text',
    },
    next: 's13',
    branches: {},
  },
  {
    id: 's13',
    type: 'condition',
    params: {
      variable: 'empresa.nivel',
      operator: 'greater_than_or_equal',
      value: '3',
    },
    next: null,
    branches: { true: 's14', false: 's16' },
  },
  {
    id: 's14',
    type: 'create_ticket',
    params: {
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático de WhatsApp.',
      team_id: level3to5TeamId || teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
      priority: 'medium',
    },
    next: 's15',
    branches: {},
  },
  {
    id: 's15',
    type: 'ai_triage',
    params: { team_id: level3to5TeamId || '' },
    next: null,
    branches: {},
  },
  // Niveis 1-2 (12-14): a IA tenta resolver de verdade primeiro. So cria o
  // ticket no final - resolvido (fecha direto) ou encaminhado (handoff) -
  // nunca antes de saber qual dos dois aconteceu.
  {
    id: 's16',
    type: 'ai_resolve',
    params: {
      assistant_id: assistantId,
      max_turns: 6,
      title: '{{empresa.nome}} | {{contato.nome}}',
      description: 'Atendimento aberto pelo fluxo automático de WhatsApp.',
      team_id: teamId,
      ticket_column_id: ticketColumnId,
      ticket_category_id: ticketCategoryId,
    },
    next: null,
    branches: {},
  },
  // CNPJ manual (6-8): cliente novo sem empresa vinculada, ou que recusou a
  // empresa sugerida - pede o CNPJ, localiza e confirma antes de voltar ao
  // fluxo principal (s3, checar bloqueio). Nao encontrado (7.2): informa e
  // encaminha para humano, nunca assume que e cliente sem validar.
  {
    id: 's17',
    type: 'ask',
    params: {
      content: 'Certo. Por favor, informe o CNPJ da empresa sobre a qual você deseja falar.',
      save_as: 'resposta.cnpj',
      answer_type: 'cnpj',
      retry_message: 'Esse CNPJ não parece válido. Pode conferir e enviar de novo?',
    },
    next: 's18',
    branches: {},
  },
  {
    id: 's18',
    type: 'find_company',
    params: { cnpj_from: 'resposta.cnpj' },
    next: 's20',
    branches: { not_found: 's19' },
  },
  {
    id: 's19',
    type: 'handoff',
    params: {
      content:
        'Não encontrei o CNPJ informado entre nossos clientes. Vou transferir você para um atendente.',
      reason: 'cnpj_nao_encontrado',
    },
    next: null,
    branches: {},
  },
  {
    id: 's20',
    type: 'send_message',
    params: {
      content:
        'Encontrei a empresa {{empresa.nome}}, CNPJ {{empresa.cnpj}}. Vamos prosseguir com o atendimento referente a ela.',
    },
    next: 's3',
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
    branches: { true: 's14', false: 's22' },
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
    next: 's22',
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
  // Antes de acionar a IA (nivel 1-2 ou 3-5), o cliente so respondeu
  // perguntas de identificacao - nunca disse o que precisa. Sem perguntar
  // aqui, a IA de resolucao recebia um historico sem nenhum problema
  // declarado e podia responder vazio (sem texto, sem handoff de verdade) -
  // ver o mesmo ajuste no modelo do WhatsApp.
  {
    id: 's22',
    type: 'ask',
    params: {
      content:
        'Certo! Agora me conta: o que está acontecendo? Pode descrever o problema com o máximo de detalhes possível.',
      save_as: 'resposta.problema',
      answer_type: 'text',
    },
    next: 's18',
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
