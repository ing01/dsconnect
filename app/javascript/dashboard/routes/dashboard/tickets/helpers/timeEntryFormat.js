// Formatacao do tempo dos apontamentos. O servidor guarda horas decimais (1,5 = 1h30);
// a tela mostra e edita em horas e minutos, que e' como se le um relogio.

const pad = value => String(value).padStart(2, '0');

/**
 * O relogio do cronometro: HH:MM:SS.
 * @param {number} totalSeconds segundos corridos
 * @returns {string} ex.: `01:05:09`
 */
export const formatClock = totalSeconds => {
  const seconds = Math.max(0, Math.floor(Number(totalSeconds) || 0));
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds % 60)}`;
};

/**
 * Horas decimais em horas e minutos inteiros.
 * @param {number|string} decimalHours ex.: `1.5`
 * @returns {{hours: number, minutes: number}} ex.: `{ hours: 1, minutes: 30 }`
 */
export const splitHours = decimalHours => {
  const totalMinutes = Math.round((Number(decimalHours) || 0) * 60);
  return { hours: Math.floor(totalMinutes / 60), minutes: totalMinutes % 60 };
};

/**
 * Horas e minutos digitados em horas decimais, com as 2 casas que o servidor guarda.
 * @param {number|string} hours horas
 * @param {number|string} minutes minutos
 * @returns {number} ex.: `1h25` vira `1.42`
 */
export const joinHours = (hours, minutes) =>
  Math.round(((Number(hours) || 0) + (Number(minutes) || 0) / 60) * 100) / 100;

/**
 * Duracao legivel de um apontamento.
 * @param {number|string} decimalHours horas decimais
 * @returns {string} `1h30min`, `2h`, `45min` ou `<1min`
 */
export const formatDuration = decimalHours => {
  const { hours, minutes } = splitHours(decimalHours);
  if (!hours && !minutes) return Number(decimalHours) > 0 ? '<1min' : '0min';
  if (!hours) return `${minutes}min`;
  return minutes ? `${hours}h${pad(minutes)}min` : `${hours}h`;
};
