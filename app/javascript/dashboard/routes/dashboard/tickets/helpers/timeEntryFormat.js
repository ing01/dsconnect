// Formatacao do tempo dos apontamentos. O servidor guarda horas decimais com 4 casas
// (1,5 = 1h30); a tela mostra e edita em horas, minutos e segundos, que e' como se le
// um relogio.

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
 * Horas decimais em segundos inteiros.
 * @param {number|string} decimalHours ex.: `0.0333`
 * @returns {number} ex.: `120`
 */
export const hoursToSeconds = decimalHours =>
  Math.round((Number(decimalHours) || 0) * 3600);

/**
 * Horas decimais como relogio exato (para a dica ao passar o mouse).
 * @param {number|string} decimalHours ex.: `0.0333`
 * @returns {string} ex.: `00:02:00`
 */
export const hoursToClock = decimalHours =>
  formatClock(hoursToSeconds(decimalHours));

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
 * Horas e minutos digitados em horas decimais, com as 4 casas que o servidor guarda
 * (com 2 casas, 1 minuto virava 0,02 h e o total deixava de bater).
 * @param {number|string} hours horas
 * @param {number|string} minutes minutos
 * @returns {number} ex.: `1h25` vira `1.4167`
 */
export const joinHours = (hours, minutes) =>
  Math.round(((Number(hours) || 0) + (Number(minutes) || 0) / 60) * 10000) /
  10000;

/**
 * Duracao legivel de um apontamento ou do total, ate o segundo.
 * @param {number|string} decimalHours horas decimais
 * @returns {string} `1h30min`, `2h`, `2min07s`, `45s` ou `0min`
 */
export const formatDuration = decimalHours => {
  const total = hoursToSeconds(decimalHours);
  if (total <= 0) return '0min';

  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;

  let text = '';
  if (hours) text += `${hours}h`;
  if (minutes) text += hours ? `${pad(minutes)}min` : `${minutes}min`;
  if (seconds) text += hours || minutes ? `${pad(seconds)}s` : `${seconds}s`;
  return text;
};

const normalize = text =>
  String(text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

/**
 * A categoria do apontamento que combina com a Mesa do ticket: na Mesa de
 * Implantacao o apontamento e' de implantacao, na de Desenvolvimento e' de
 * desenvolvimento. Vem do NOME da Mesa (como o resto do sistema ja faz para achar a
 * Mesa de Desenvolvimento), ignorando acento e maiuscula.
 * @param {string} teamName nome da Mesa do ticket
 * @returns {string|null} 'implantacao', 'desenvolvimento', 'dev_geral' ou null
 */
export const categoryForTeamName = teamName => {
  const name = normalize(teamName);
  if (/dev(\.|\s|_)*geral/.test(name)) return 'dev_geral';
  if (name.includes('desenvolv')) return 'desenvolvimento';
  if (name.includes('implanta')) return 'implantacao';
  return null;
};
