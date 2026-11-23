/**
 * Formata uma espera em segundos para leitura rápida no painel:
 * "menos de 1 min", "7 min", "1 h 05 min", "2 d 3 h".
 */
export const formatWait = seconds => {
  if (seconds === null || seconds === undefined || Number.isNaN(seconds)) {
    return '';
  }

  const totalMinutes = Math.floor(Math.max(seconds, 0) / 60);
  if (totalMinutes < 1) return 'menos de 1 min';
  if (totalMinutes < 60) return `${totalMinutes} min`;

  const totalHours = Math.floor(totalMinutes / 60);
  if (totalHours < 24) {
    return `${totalHours} h ${String(totalMinutes % 60).padStart(2, '0')} min`;
  }

  return `${Math.floor(totalHours / 24)} d ${totalHours % 24} h`;
};

/**
 * Segundos de espera de uma conversa agora; `null` quando o agente já
 * respondeu (sem `waiting_since`). `nowMs` já vem corrigido pela diferença de
 * relógio entre o servidor e o navegador.
 */
export const waitSeconds = (waitingSince, nowMs) => {
  if (!waitingSince) return null;
  const since = Date.parse(waitingSince);
  if (Number.isNaN(since)) return null;
  return Math.max(Math.floor((nowMs - since) / 1000), 0);
};
