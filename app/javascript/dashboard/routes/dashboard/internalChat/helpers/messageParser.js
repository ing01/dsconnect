/**
 * Quebra o texto de uma mensagem nos pedaços que a tela sabe desenhar:
 * texto comum, menção a um colega e referência a um Ticket.
 *
 * Feito por partes, e não por HTML montado à mão, porque nada aqui precisa
 * passar por `v-html` - cada pedaço vira um elemento próprio no template.
 */

const TICKET_PATTERN = /#(\d{3,})/g;

/**
 * @param {string} body texto cru da mensagem
 * @param {Array<{id:number,name:string}>} users pessoas que podem ser mencionadas
 * @returns {Array<{type:string,value:string,id?:number}>} pedaços em ordem
 */
export const parseMessage = (body, users = []) => {
  if (!body) return [];

  // Os nomes mais longos primeiro: sem isso "@João" casaria dentro de
  // "@João Vitor" e cortaria a menção pela metade.
  const names = users
    .map(user => user.name)
    .sort((a, b) => b.length - a.length)
    .map(name => name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));

  const mentionPattern = names.length ? `@(${names.join('|')})` : null;
  const pattern = new RegExp(
    [mentionPattern, TICKET_PATTERN.source].filter(Boolean).join('|'),
    'g'
  );

  const parts = [];
  let cursor = 0;
  let match = pattern.exec(body);

  while (match !== null) {
    if (match.index > cursor) {
      parts.push({ type: 'text', value: body.slice(cursor, match.index) });
    }

    const [full, mentionName, ticketId] = match;
    if (mentionName) {
      const user = users.find(item => item.name === mentionName);
      parts.push({ type: 'mention', value: full, id: user?.id });
    } else {
      parts.push({ type: 'ticket', value: full, id: Number(ticketId) });
    }

    cursor = match.index + full.length;
    match = pattern.exec(body);
  }

  if (cursor < body.length)
    parts.push({ type: 'text', value: body.slice(cursor) });
  return parts;
};

/**
 * Horário curto para a linha da mensagem.
 * @param {number} timestamp em milissegundos
 * @returns {string} algo como `10:32`
 */
export const shortTime = timestamp =>
  new Date(timestamp).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });

/**
 * Duas mensagens seguidas da mesma pessoa, em poucos minutos, viram um bloco
 * só - é o que mantém a leitura densa em vez de repetir avatar e nome.
 * @param {object} message mensagem atual
 * @param {object} previous mensagem anterior, se houver
 * @returns {boolean} true quando a atual continua o bloco anterior
 */
export const continuesBlock = (message, previous) => {
  if (!previous || previous.userId !== message.userId) return false;
  if (message.replyTo) return false;

  return message.createdAt - previous.createdAt < 5 * 60 * 1000;
};
