/**
 * Apresentação dos três SLAs do Ticket.
 *
 * Nada aqui decide vencimento: o backend é a fonte de verdade e já manda
 * `status` e `due_at`. Estas funções apenas formatam e fazem a contagem
 * regressiva entre uma atualização e outra.
 */

const SECOND = 1;
const MINUTE = 60;
const HOUR = 3600;
const DAY = 86400;

/**
 * Formata uma duração no padrão da tela: `04d 19h 2m`.
 *
 * Dias e horas são zero-padded porque a coluna fica alinhada; os minutos não,
 * como no exemplo. Abaixo de um minuto mostra `0m` em vez de segundos, que
 * mudariam rápido demais para serem lidos.
 * @param {number} seconds duração em segundos (o sinal é ignorado)
 * @returns {string} duração formatada
 */
export const formatSlaDuration = seconds => {
  const total = Math.abs(Math.floor(seconds / SECOND));
  const days = Math.floor(total / DAY);
  const hours = Math.floor((total % DAY) / HOUR);
  const minutes = Math.floor((total % HOUR) / MINUTE);

  return `${String(days).padStart(2, '0')}d ${String(hours).padStart(2, '0')}h ${minutes}m`;
};

/**
 * Converte segundos no formato configurável `HH:MM` — onde as horas não têm
 * teto, então `30:00` são trinta horas, não um dia e seis.
 * @param {number|null} seconds prazo em segundos
 * @returns {string} prazo no formato HH:MM, ou string vazia quando não há prazo
 */
export const secondsToHoursMinutes = seconds => {
  if (!seconds && seconds !== 0) return '';

  const total = Math.floor(seconds);
  const hours = Math.floor(total / HOUR);
  const minutes = Math.floor((total % HOUR) / MINUTE);

  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
};

/**
 * O caminho inverso, para o que o usuário digita na configuração.
 *
 * Devolve `null` para entrada vazia — que é como se diz "esta prioridade/estágio
 * não tem prazo" — e para qualquer coisa que não seja `HH:MM` válido.
 * @param {string} value texto digitado
 * @returns {number|null} prazo em segundos
 */
export const hoursMinutesToSeconds = value => {
  const match = String(value ?? '')
    .trim()
    .match(/^(\d{1,4}):([0-5]\d)$/);
  if (!match) return null;

  const seconds = Number(match[1]) * HOUR + Number(match[2]) * MINUTE;
  return seconds > 0 ? seconds : null;
};

/**
 * O estado visual de um relógio.
 *
 * Os três estados são independentes entre si, e um relógio já encerrado nunca
 * muda de resposta — por isso `hit` continua `hit` mesmo depois do prazo.
 * @param {object} sla relógio vindo do backend
 * @returns {'hit'|'missed'|'running'} estado a apresentar
 */
export const slaState = sla => {
  if (!sla) return 'running';
  if (sla.status === 'hit') return 'hit';
  // O backend marca `missed` na varredura; entre uma varredura e outra a tela
  // não pode fingir que ainda está no prazo.
  if (sla.status === 'missed' || sla.due_at * 1000 < Date.now()) return 'missed';
  return 'running';
};

/**
 * Segundos restantes de um relógio, contados no cliente entre atualizações.
 *
 * Um relógio encerrado congela no instante em que encerrou — o que interessa
 * nele é o resultado, não quanto tempo passou desde então.
 * @param {object} sla relógio vindo do backend
 * @param {number} now instante de referência em milissegundos
 * @returns {number} segundos restantes, negativos quando o prazo passou
 */
export const slaRemainingSeconds = (sla, now = Date.now()) => {
  if (!sla) return 0;

  const reference = sla.completed_at ? sla.completed_at * 1000 : now;
  return Math.floor((sla.due_at * 1000 - reference) / 1000);
};
