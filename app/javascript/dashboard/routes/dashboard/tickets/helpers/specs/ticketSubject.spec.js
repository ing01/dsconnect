import { ticketSubject } from '../ticketSubject';

describe('ticketSubject', () => {
  it('builds [EMPRESA] | [SOLICITANTE] | [TITULO]', () => {
    expect(
      ticketSubject({
        company_name: 'HG SERVICOS',
        requester_name: 'FINANCEIRO',
        title: 'ATUALIZACAO DE VALORES',
      })
    ).toBe('[HG SERVICOS] | [FINANCEIRO] | [ATUALIZACAO DE VALORES]');
  });

  it('skips the parts the ticket does not have', () => {
    expect(ticketSubject({ title: 'Erro ao gerar NFe' })).toBe(
      '[Erro ao gerar NFe]'
    );
    expect(ticketSubject({ company_name: 'ACME', title: 'Erro' })).toBe(
      '[ACME] | [Erro]'
    );
  });

  it('falls back to the contact name when there is no requester_name', () => {
    expect(ticketSubject({ contact: { name: 'Joana' }, title: 'Erro' })).toBe(
      '[Joana] | [Erro]'
    );
  });

  it('keeps an imported ticket title as it came', () => {
    expect(
      ticketSubject({
        company_name: 'ACME',
        title: '[ACME] ja vinha pronto',
        custom_attributes: { imported_ticket_number: 12 },
      })
    ).toBe('[ACME] ja vinha pronto');
  });
});
