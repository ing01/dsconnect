import {
  ALERT_KIND,
  alertKindForRoute,
  alertKindForTabKey,
  tabHasAlert,
  withTitleAlert,
} from '../unreadAlerts';

describe('alertKindForRoute', () => {
  it('as telas de conversa avisam sobre conversas', () => {
    [
      'home',
      'inbox_conversation',
      'team_conversations',
      'conversation_mentions',
    ].forEach(name =>
      expect(alertKindForRoute(name)).toBe(ALERT_KIND.CONVERSATIONS)
    );
  });

  it('o chat interno avisa sobre o chat interno', () => {
    expect(alertKindForRoute('internal_chat')).toBe(ALERT_KIND.INTERNAL_CHAT);
  });

  it('as outras telas nao avisam', () => {
    expect(alertKindForRoute('tickets_index')).toBeNull();
    expect(alertKindForRoute('principal')).toBeNull();
    expect(alertKindForRoute(undefined)).toBeNull();
  });
});

describe('alertKindForTabKey', () => {
  it('le a rota no comeco da chave da aba', () => {
    expect(alertKindForTabKey('home|[]')).toBe(ALERT_KIND.CONVERSATIONS);
    expect(alertKindForTabKey('internal_chat|[]')).toBe(
      ALERT_KIND.INTERNAL_CHAT
    );
    expect(alertKindForTabKey('tickets_index|[]')).toBeNull();
    expect(alertKindForTabKey('')).toBeNull();
  });
});

describe('tabHasAlert', () => {
  it('a aba de conversas so avisa por conversas, a do chat so pelo chat', () => {
    const soConversas = { conversations: true, internalChat: false };
    const soChat = { conversations: false, internalChat: true };

    expect(tabHasAlert('home|[]', soConversas)).toBe(true);
    expect(tabHasAlert('home|[]', soChat)).toBe(false);
    expect(tabHasAlert('internal_chat|[]', soChat)).toBe(true);
    expect(tabHasAlert('internal_chat|[]', soConversas)).toBe(false);
  });

  it('abas de outras telas nunca avisam', () => {
    expect(
      tabHasAlert('tickets_index|[]', {
        conversations: true,
        internalChat: true,
      })
    ).toBe(false);
  });
});

describe('withTitleAlert', () => {
  it('poe o aviso no inicio do titulo', () => {
    expect(withTitleAlert('DSConnect', true)).toBe('(!) DSConnect');
  });

  it('nao acumula o aviso', () => {
    expect(withTitleAlert('(!) DSConnect', true)).toBe('(!) DSConnect');
  });

  it('tira o aviso quando nao ha mais', () => {
    expect(withTitleAlert('(!) DSConnect', false)).toBe('DSConnect');
    expect(withTitleAlert('DSConnect', false)).toBe('DSConnect');
  });

  it('aguenta titulo vazio', () => {
    expect(withTitleAlert('', false)).toBe('');
    expect(withTitleAlert(undefined, true)).toBe('(!) ');
  });
});
