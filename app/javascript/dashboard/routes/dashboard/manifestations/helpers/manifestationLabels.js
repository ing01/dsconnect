/**
 * Os rótulos do SAC: tipos, assuntos e status.
 *
 * Um arquivo só, usado pela tela interna E pela do Portal. Duas listas - uma de
 * cada lado - divergiriam no dia em que um tipo novo fosse criado, e o cliente
 * veria um rótulo que a equipe não vê.
 *
 * Os valores são os mesmos dos enums do `Manifestation`; as traduções moram em
 * `MANIFESTATION.KINDS.*`, `MANIFESTATION.SUBJECT_AREAS.*` e
 * `MANIFESTATION.STATUSES.*`.
 */

export const KINDS = [
  'suggestion',
  'complaint',
  'compliment',
  'improvement',
  'other',
];

export const SUBJECT_AREAS = [
  'erp',
  'support',
  'agent',
  'implementation',
  'portal',
  'commercial',
  'other',
];

export const STATUSES = [
  'received',
  'under_review',
  'in_progress',
  'awaiting_customer',
  'completed',
  'cancelled',
];

// Os estados em que nada mais se espera - o mesmo par do
// `Manifestation::FINISHED_STATUSES`.
export const FINISHED_STATUSES = ['completed', 'cancelled'];

// `Label.vue` valida `color` contra uma lista fechada e, para qualquer outro
// valor, renderiza SEM fundo - foi assim que `green` e `violet` produziram
// crachás invisíveis no módulo de Tickets. Só cores dessa lista aqui.
export const STATUS_LABEL_COLORS = {
  received: 'blue',
  under_review: 'iris',
  in_progress: 'amber',
  awaiting_customer: 'ruby',
  completed: 'teal',
  cancelled: 'slate',
};

export const KIND_LABEL_COLORS = {
  suggestion: 'blue',
  complaint: 'ruby',
  compliment: 'teal',
  improvement: 'iris',
  other: 'slate',
};

export const statusColor = status => STATUS_LABEL_COLORS[status] || 'slate';

export const kindColor = kind => KIND_LABEL_COLORS[kind] || 'slate';

export const isFinished = status => FINISHED_STATUSES.includes(status);

// As opções de um `<select>`, já traduzidas. Recebe o `t` em vez de importar o
// i18n: é o que mantém o helper testável sem montar a aplicação inteira.
export const kindOptions = t =>
  KINDS.map(value => ({ value, label: t(`MANIFESTATION.KINDS.${value}`) }));

export const subjectAreaOptions = t =>
  SUBJECT_AREAS.map(value => ({
    value,
    label: t(`MANIFESTATION.SUBJECT_AREAS.${value}`),
  }));

export const statusOptions = t =>
  STATUSES.map(value => ({
    value,
    label: t(`MANIFESTATION.STATUSES.${value}`),
  }));
