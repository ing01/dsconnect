/**
 * Apresentacao da disponibilidade de um agente.
 *
 * Os valores vem do proprio produto (`availability_status`), entao o Chat nao
 * inventa presenca nem monta infraestrutura propria - so pinta o que ja existe.
 */

const DOT_CLASSES = {
  online: 'bg-n-teal-9',
  busy: 'bg-n-amber-9',
  offline: 'bg-n-slate-7',
};

/**
 * @param {string} status disponibilidade do agente
 * @returns {string} classe de cor do ponto de presenca
 */
export const presenceDotClass = status =>
  DOT_CLASSES[status] || DOT_CLASSES.offline;

/**
 * @param {string} status disponibilidade do agente
 * @returns {string} chave de traducao do rotulo
 */
export const presenceLabelKey = status =>
  `INTERNAL_CHAT.PRESENCE.${(DOT_CLASSES[status] ? status : 'offline').toUpperCase()}`;
