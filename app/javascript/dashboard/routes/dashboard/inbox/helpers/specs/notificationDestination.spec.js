import { notificationDestinationFor } from '../notificationDestination';

describe('notificationDestinationFor', () => {
  it('sends a Chat Interno message to its room by query', () => {
    const destino = notificationDestinationFor(
      { primaryActorType: 'ChatMessage', primaryActor: { chatChannelId: 7 } },
      1
    );

    expect(destino).toEqual({
      name: 'internal_chat',
      params: { accountId: 1 },
      query: { room: 7 },
    });
  });

  it('returns null for a Chat Interno message with no room', () => {
    const destino = notificationDestinationFor(
      { primaryActorType: 'ChatMessage', primaryActor: {} },
      1
    );

    expect(destino).toBeNull();
  });

  // O defeito real: antes disto, uma notificacao de sugestao caia no
  // fallback de conversa abaixo e abria uma conversa errada (o id da
  // sugestao coincidindo por acaso com o de uma conversa qualquer).
  it('opens the Suggestions board with the suggestion marked in the query', () => {
    const destino = notificationDestinationFor(
      { primaryActorType: 'Suggestion', primaryActor: { id: 42 } },
      1
    );

    expect(destino).toEqual({
      name: 'suggestions_index',
      params: { accountId: 1 },
      query: { suggestion: 42 },
    });
  });

  it('returns null for a Suggestion without an id', () => {
    const destino = notificationDestinationFor(
      { primaryActorType: 'Suggestion', primaryActor: {} },
      1
    );

    expect(destino).toBeNull();
  });

  it('sends a customer-reply ticket notification straight to the Comunicacao tab', () => {
    const destino = notificationDestinationFor(
      {
        primaryActorType: 'Ticket',
        notificationType: 'ticket_customer_communication_received',
        primaryActor: { id: 99 },
      },
      1
    );

    expect(destino).toEqual({
      name: 'ticket_detail',
      params: { accountId: 1, ticketId: 99 },
      query: { tab: 'communication' },
    });
  });

  it('sends every other Ticket notification to the Triagem queue, not a specific ticket', () => {
    const destino = notificationDestinationFor(
      {
        primaryActorType: 'Ticket',
        notificationType: 'ticket_triage_pending',
        primaryActor: { id: 99 },
      },
      1
    );

    expect(destino).toEqual({
      name: 'tickets_triage',
      params: { accountId: 1 },
    });
  });

  it.each(['Article', 'Portal'])(
    'returns null for a %s notification (handled elsewhere)',
    primaryActorType => {
      const destino = notificationDestinationFor(
        { primaryActorType, primaryActor: { id: 1 } },
        1
      );

      expect(destino).toBeNull();
    }
  );

  it('falls back to the conversation route for every other actor type', () => {
    const destino = notificationDestinationFor(
      {
        primaryActorType: 'Conversation',
        primaryActor: { id: 5, inboxId: 3 },
      },
      1
    );

    expect(destino).toEqual({
      name: 'inbox_view_conversation',
      params: { inboxId: 3, type: 'conversation', id: 5 },
    });
  });

  it('returns null for the conversation fallback without a conversation id', () => {
    const destino = notificationDestinationFor(
      { primaryActorType: 'Conversation', primaryActor: {} },
      1
    );

    expect(destino).toBeNull();
  });
});
