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
        options: ['text', 'cnpj'],
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
];

export const findStepType = type =>
  FLOW_STEP_TYPES.find(definition => definition.type === type);

// As variaveis que o fluxo oferece. As de `resposta.` dependem do que cada
// etapa `ask` guardou, entao sao lidas do proprio fluxo em vez de listadas fixo.
export const BASE_VARIABLES = [
  'empresa.nome',
  'empresa.cnpj',
  'empresa.id',
  'contato.nome',
  'contato.email',
  'ticket.numero',
  'ticket.titulo',
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
