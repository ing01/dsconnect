// Para onde o clique numa notificacao leva, por tipo de ator. Extraido de
// InboxList.vue como funcao pura (recebe `accountId` em vez de ler
// `route.params` direto) justamente para poder testar cada ramo sem montar a
// tela inteira - ela arrasta Vuex, infinite scroll e o menu de contexto.
//
// Nem todo aviso vem de uma conversa: o do Chat Interno tem uma ChatMessage
// como ator, sem inbox e sem conversa, e a rota de conversa ficava com
// `inboxId` indefinido - o clique nao ia a lugar nenhum, sem erro visivel.
// Sugestao e Ticket tinham o mesmo problema: caiam no fallback de conversa
// la' embaixo e abriam uma conversa errada (o id de uma conversa qualquer,
// coincidindo por acaso com o id da Sugestao/do Ticket).
export const notificationDestinationFor = (notificationItem, accountId) => {
  const { primaryActorType, primaryActor, notificationType } = notificationItem;

  if (primaryActorType === 'ChatMessage') {
    const room = primaryActor?.chatChannelId;
    if (!room) return null;

    // A tela do Chat Interno escolhe a sala pela query `room`.
    return {
      name: 'internal_chat',
      params: { accountId },
      query: { room },
    };
  }

  // `?suggestion=` e o que SuggestionsPage.vue le para abrir o card certo
  // direto, em vez de so' levar ao quadro.
  if (primaryActorType === 'Suggestion') {
    if (!primaryActor?.id) return null;

    return {
      name: 'suggestions_index',
      params: { accountId },
      query: { suggestion: primaryActor.id },
    };
  }

  // A resposta do cliente leva direto a aba de Comunicacao daquele ticket;
  // os demais avisos de Ticket (hoje so' a Triagem) levam pra fila, sem um
  // ticket especifico pra abrir.
  if (primaryActorType === 'Ticket') {
    if (notificationType === 'ticket_customer_communication_received') {
      if (!primaryActor?.id) return null;

      return {
        name: 'ticket_detail',
        params: { accountId, ticketId: primaryActor.id },
        query: { tab: 'communication' },
      };
    }

    return {
      name: 'tickets_triage',
      params: { accountId },
    };
  }

  // Artigo/Portal tambem tem `id` - sem este desvio, cairia no fallback de
  // conversa abaixo e abriria uma conversa errada.
  if (primaryActorType === 'Article' || primaryActorType === 'Portal') {
    return null;
  }

  const { inboxId, id: conversationId } = primaryActor ?? {};
  if (!conversationId) return null;

  return {
    name: 'inbox_view_conversation',
    params: { inboxId, type: 'conversation', id: conversationId },
  };
};
