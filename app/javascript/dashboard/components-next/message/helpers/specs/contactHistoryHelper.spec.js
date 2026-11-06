import {
  prependHistory,
  indexConversations,
  startsConversationBlock,
  formatHistoryDate,
} from '../contactHistoryHelper';

describe('contactHistoryHelper', () => {
  describe('prependHistory', () => {
    it('coloca a pagina mais antiga antes do que ja estava carregado', () => {
      const current = [{ id: 5 }, { id: 6 }];
      const incoming = [{ id: 3 }, { id: 4 }];

      expect(prependHistory(current, incoming).map(m => m.id)).toEqual([
        3, 4, 5, 6,
      ]);
    });

    it('nao repete mensagem que ja esta na lista', () => {
      const current = [{ id: 5 }, { id: 6 }];
      const incoming = [{ id: 4 }, { id: 5 }];

      expect(prependHistory(current, incoming).map(m => m.id)).toEqual([
        4, 5, 6,
      ]);
    });

    it('funciona com a lista vazia', () => {
      expect(prependHistory([], [{ id: 1 }]).map(m => m.id)).toEqual([1]);
      expect(prependHistory(undefined, undefined)).toEqual([]);
    });
  });

  describe('indexConversations', () => {
    it('indexa pelo display_id e mantem as conversas ja conhecidas', () => {
      const current = { 10: { display_id: 10, inbox_name: 'WhatsApp' } };
      const incoming = [{ display_id: 11, inbox_name: 'Portal' }];

      expect(indexConversations(current, incoming)).toEqual({
        10: { display_id: 10, inbox_name: 'WhatsApp' },
        11: { display_id: 11, inbox_name: 'Portal' },
      });
    });

    it('aceita resposta sem conversas', () => {
      expect(indexConversations({ 1: { display_id: 1 } }, undefined)).toEqual({
        1: { display_id: 1 },
      });
    });
  });

  describe('startsConversationBlock', () => {
    const messages = [
      { id: 1, conversationId: 10 },
      { id: 2, conversationId: 10 },
      { id: 3, conversationId: 11 },
    ];

    it('abre bloco na primeira mensagem e quando a conversa muda', () => {
      expect(startsConversationBlock(messages, 0)).toBe(true);
      expect(startsConversationBlock(messages, 1)).toBe(false);
      expect(startsConversationBlock(messages, 2)).toBe(true);
    });
  });

  describe('formatHistoryDate', () => {
    it('devolve texto vazio sem data', () => {
      expect(formatHistoryDate(null, 'pt-BR')).toBe('');
    });

    it('formata dia/mes/ano e hora', () => {
      const text = formatHistoryDate(1730851200, 'pt-BR');

      expect(text).toMatch(/\d{2}\/\d{2}\/\d{4}/);
    });
  });
});
