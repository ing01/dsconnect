import { NOTIFICATION_TYPES_MAPPING } from '../InboxViewHelpers';

// Pedido: notificacao de triagem (e a de resposta do cliente num ticket)
// chegava sem icone/cor na aba de Notificacoes porque o tipo nao estava
// neste mapa - o card caia no par vazio (`|| []`) do InboxCard.vue.
describe('NOTIFICATION_TYPES_MAPPING', () => {
  it('has an entry for TICKET_TRIAGE_PENDING', () => {
    expect(NOTIFICATION_TYPES_MAPPING.TICKET_TRIAGE_PENDING).toBeDefined();
    const [icon, color] = NOTIFICATION_TYPES_MAPPING.TICKET_TRIAGE_PENDING;
    expect(icon).toBeTruthy();
    expect(color).toBeTruthy();
  });

  it('has an entry for TICKET_CUSTOMER_COMMUNICATION_RECEIVED', () => {
    expect(
      NOTIFICATION_TYPES_MAPPING.TICKET_CUSTOMER_COMMUNICATION_RECEIVED
    ).toBeDefined();
  });
});
