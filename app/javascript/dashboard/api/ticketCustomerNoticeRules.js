import ApiClient from './ApiClient';

// Mensagens automaticas ao cliente: "quando o ticket entrar neste Estagio (ou
// passar para esta Mesa), envie este texto".
class TicketCustomerNoticeRulesAPI extends ApiClient {
  constructor() {
    super('ticket_customer_notice_rules', { accountScoped: true });
  }
}

export default new TicketCustomerNoticeRulesAPI();
