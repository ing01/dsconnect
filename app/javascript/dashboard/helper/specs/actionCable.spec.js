import { describe, it, beforeEach, afterEach, expect, vi } from 'vitest';
import ActionCableConnector from '../actionCable';
import { useTicketWorkspace } from 'dashboard/routes/dashboard/tickets/composables/useTicketWorkspace';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
  },
}));

vi.mock('dashboard/composables/useImpersonation', () => ({
  useImpersonation: () => ({
    isImpersonating: { value: false },
  }),
}));

global.chatwootConfig = {
  websocketURL: 'wss://test.chatwoot.com',
};

const mockRetryJitter = value =>
  vi.spyOn(Math, 'random').mockReturnValue(value);

describe('ActionCableConnector - Copilot Tests', () => {
  let store;
  let actionCable;
  let mockDispatch;

  beforeEach(() => {
    vi.clearAllMocks();
    mockDispatch = vi.fn();
    store = {
      $store: {
        dispatch: mockDispatch,
        getters: {
          getCurrentAccountId: 1,
          'accounts/isFeatureEnabledonAccount': vi.fn(() => true),
        },
      },
    };

    actionCable = ActionCableConnector.init(store.$store, 'test-token');
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.clearAllTimers();
    vi.useRealTimers();
  });
  describe('copilot event handlers', () => {
    it('should register the copilot.message.created event handler', () => {
      expect(Object.keys(actionCable.events)).toContain(
        'copilot.message.created'
      );
      expect(actionCable.events['copilot.message.created']).toBe(
        actionCable.onCopilotMessageCreated
      );
    });

    it('should handle the copilot.message.created event through the ActionCable system', () => {
      const copilotData = {
        id: 2,
        content: 'This is a copilot message from ActionCable',
        conversation_id: 456,
        created_at: '2025-05-27T15:58:04-06:00',
        account_id: 1,
      };
      actionCable.onReceived({
        event: 'copilot.message.created',
        data: copilotData,
      });
      expect(mockDispatch).toHaveBeenCalledWith(
        'copilotMessages/upsert',
        copilotData
      );
    });
  });

  describe('conversation unread count event handlers', () => {
    it('should register the conversation.unread_count_changed event handler', () => {
      expect(Object.keys(actionCable.events)).toContain(
        'conversation.unread_count_changed'
      );
      expect(actionCable.events['conversation.unread_count_changed']).toBe(
        actionCable.onConversationUnreadCountChanged
      );
    });

    it('should refetch unread counts when unread count changes', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
      mockRetryJitter(0.5);

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledWith('conversationUnreadCounts/get');

      vi.advanceTimersByTime(37499);
      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(1);
      expect(mockDispatch).toHaveBeenCalledTimes(2);
      expect(mockDispatch).toHaveBeenLastCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('does not retry unread count changes when filtered counts are disabled', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
      store.$store.getters[
        'accounts/isFeatureEnabledonAccount'
      ].mockImplementation(
        (_, featureFlag) =>
          featureFlag === FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
      );

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(45000);
      expect(mockDispatch).toHaveBeenCalledTimes(1);
    });

    it('delays unread count refetch when a conversation is mentioned', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));

      const conversation = { id: 1, account_id: 1 };

      actionCable.onReceived({
        event: 'conversation.mentioned',
        data: conversation,
      });

      expect(mockDispatch).toHaveBeenCalledWith('addMentions', conversation);
      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );

      vi.advanceTimersByTime(4999);
      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );

      vi.advanceTimersByTime(1);
      expect(mockDispatch).toHaveBeenCalledWith('conversationUnreadCounts/get');
    });

    it('does not schedule mention unread count fetches when filtered counts are disabled', () => {
      vi.useFakeTimers();
      store.$store.getters[
        'accounts/isFeatureEnabledonAccount'
      ].mockImplementation(
        (_, featureFlag) =>
          featureFlag === FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
      );

      const conversation = { id: 1, account_id: 1 };

      actionCable.onReceived({
        event: 'conversation.mentioned',
        data: conversation,
      });

      expect(mockDispatch).toHaveBeenCalledWith('addMentions', conversation);

      vi.advanceTimersByTime(45000);
      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('retries mentioned unread counts after the backend refresh window', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
      mockRetryJitter(0.5);

      actionCable.onReceived({
        event: 'conversation.mentioned',
        data: { id: 1, account_id: 1 },
      });

      const unreadCountFetches = () =>
        mockDispatch.mock.calls.filter(
          ([action]) => action === 'conversationUnreadCounts/get'
        );

      vi.advanceTimersByTime(5000);
      expect(unreadCountFetches()).toHaveLength(1);

      vi.advanceTimersByTime(32499);
      expect(unreadCountFetches()).toHaveLength(1);

      vi.advanceTimersByTime(1);
      expect(unreadCountFetches()).toHaveLength(2);
    });

    it('reschedules mentioned unread count retries for later invalidations', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
      mockRetryJitter(0);

      const unreadCountFetches = () =>
        mockDispatch.mock.calls.filter(
          ([action]) => action === 'conversationUnreadCounts/get'
        );

      actionCable.onReceived({
        event: 'conversation.mentioned',
        data: { id: 1, account_id: 1 },
      });

      vi.advanceTimersByTime(5000);
      expect(unreadCountFetches()).toHaveLength(1);

      vi.advanceTimersByTime(10000);
      actionCable.onReceived({
        event: 'conversation.mentioned',
        data: { id: 1, account_id: 1 },
      });

      vi.advanceTimersByTime(5000);
      expect(unreadCountFetches()).toHaveLength(2);

      vi.advanceTimersByTime(10000);
      expect(unreadCountFetches()).toHaveLength(2);

      vi.advanceTimersByTime(15000);
      expect(unreadCountFetches()).toHaveLength(3);
    });

    it('refetches filtered unread counts after account cache invalidation', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));
      mockRetryJitter(0.5);

      const cacheKeys = {
        label: 'label-key',
        inbox: 'inbox-key',
        team: 'team-key',
      };
      const unreadCountFetches = () =>
        mockDispatch.mock.calls.filter(
          ([action]) => action === 'conversationUnreadCounts/get'
        );

      actionCable.onReceived({
        event: 'account.cache_invalidated',
        data: { account_id: 1, cache_keys: cacheKeys },
      });

      expect(mockDispatch).toHaveBeenCalledWith('labels/revalidate', {
        newKey: cacheKeys.label,
      });
      expect(mockDispatch).toHaveBeenCalledWith('inboxes/revalidate', {
        newKey: cacheKeys.inbox,
      });
      expect(mockDispatch).toHaveBeenCalledWith('teams/revalidate', {
        newKey: cacheKeys.team,
      });
      expect(unreadCountFetches()).toHaveLength(1);

      vi.advanceTimersByTime(37499);
      expect(unreadCountFetches()).toHaveLength(1);

      vi.advanceTimersByTime(1);
      expect(unreadCountFetches()).toHaveLength(2);
    });

    it('does not refetch unread counts after cache invalidation when filtered counts are disabled', () => {
      vi.useFakeTimers();
      store.$store.getters[
        'accounts/isFeatureEnabledonAccount'
      ].mockImplementation(
        (_, featureFlag) =>
          featureFlag === FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS
      );

      actionCable.onReceived({
        event: 'account.cache_invalidated',
        data: {
          account_id: 1,
          cache_keys: {
            label: 'label-key',
            inbox: 'inbox-key',
            team: 'team-key',
          },
        },
      });

      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );

      vi.advanceTimersByTime(45000);
      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('does not refetch unread counts when unread count feature is disabled', () => {
      store.$store.getters[
        'accounts/isFeatureEnabledonAccount'
      ].mockReturnValue(false);

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('should throttle unread count refetches for repeated events', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(4999);
      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(1);
      expect(mockDispatch).toHaveBeenCalledTimes(2);
      expect(mockDispatch).toHaveBeenLastCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('clears pending unread count refetch before immediate refetch', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      vi.advanceTimersByTime(1000);
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      vi.setSystemTime(new Date('2026-01-01T00:00:06Z'));
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledTimes(2);

      vi.advanceTimersByTime(4000);
      expect(mockDispatch).toHaveBeenCalledTimes(2);
    });
  });
});

// A aba do workspace tem de sair junto com o card. Este e o unico ponto por
// onde passam as exclusoes que a tela nao viu acontecer - a feita por outra
// pessoa, a feita noutra aba do navegador, e a dos chamados FILHOS apagados
// junto com o pai.
describe('ActionCableConnector - exclusao de ticket', () => {
  let actionCable;
  let workspace;

  const excluir = id =>
    actionCable.onReceived({
      event: 'ticket.deleted',
      data: { ticket: { id }, ticket_id: id, account_id: 1 },
    });

  beforeEach(() => {
    vi.clearAllMocks();
    const store = {
      dispatch: vi.fn(),
      getters: {
        getCurrentAccountId: 1,
        // Fila vazia: sem isto o contador da Triagem pediria uma reconta.
        'tickets/getTriageCount': 0,
        'accounts/isFeatureEnabledonAccount': vi.fn(() => true),
      },
    };
    actionCable = ActionCableConnector.init(store, 'test-token');

    workspace = useTicketWorkspace();
    // O estado do workspace e de modulo, entao cada exemplo deixa a barra como
    // a encontrou.
    workspace.tabs.value.slice().forEach(tab => workspace.closeTab(tab.id));
  });

  afterEach(() => {
    actionCable.disconnect?.();
  });

  it('closes the workspace tab of the deleted ticket', () => {
    workspace.openTab({ id: 9, display_id: 9, title: 'Erro na emissao' });
    expect(workspace.tabs.value.map(tab => tab.id)).toEqual([9]);

    excluir(9);

    expect(workspace.tabs.value).toEqual([]);
  });

  // O pai e os filhos sao exclusoes separadas, cada uma com o seu evento. Se
  // so o pai fechasse, a aba do filho ficaria apontando para o nada.
  it('closes a child tab too, on its own event', () => {
    workspace.openTab({ id: 1, display_id: 1, title: 'Pai' });
    workspace.openTab({ id: 2, display_id: 2, title: 'Filho' });

    excluir(1);
    excluir(2);

    expect(workspace.tabs.value).toEqual([]);
  });

  // Ticket que ninguem tinha aberto nao pode mexer na barra de quem esta
  // trabalhando noutro.
  it('leaves the other tabs alone', () => {
    workspace.openTab({ id: 4, display_id: 4, title: 'Aberto' });

    excluir(77);

    expect(workspace.tabs.value.map(tab => tab.id)).toEqual([4]);
  });
});
