// Historico do cliente dentro da conversa: mensagens das conversas anteriores da
// mesma pessoa, mostradas acima das da conversa atual.

// Junta a pagina nova (mais antiga) ao que ja esta carregado, sem repetir mensagem.
export const prependHistory = (current = [], incoming = []) => {
  const known = new Set(current.map(message => message.id));
  return [...incoming.filter(message => !known.has(message.id)), ...current];
};

// Dados de cada conversa anterior, indexados pelo display_id (o mesmo
// `conversation_id` que vem em cada mensagem).
export const indexConversations = (current = {}, incoming = []) => ({
  ...current,
  ...Object.fromEntries(
    (incoming || []).map(conversation => [conversation.display_id, conversation])
  ),
});

// A mensagem abre o bloco de uma conversa quando a anterior e' de outra
// (mensagens ja convertidas para camelCase).
export const startsConversationBlock = (messages, index) =>
  index === 0 ||
  messages[index - 1].conversationId !== messages[index].conversationId;

export const formatHistoryDate = (timestamp, locale) => {
  if (!timestamp) return '';
  const options = {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  };
  const date = new Date(timestamp * 1000);
  // O idioma do app vem como "pt_BR" (com underline), que o Intl rejeita com
  // RangeError - e um erro aqui, na hora de desenhar, derrubava a lista inteira
  // de mensagens. Troca para "pt-BR" e, se ainda assim falhar, usa o padrao.
  try {
    return date.toLocaleString(String(locale || '').replace('_', '-') || undefined, options);
  } catch (error) {
    return date.toLocaleString(undefined, options);
  }
};
