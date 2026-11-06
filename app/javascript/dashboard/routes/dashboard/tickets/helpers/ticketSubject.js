// O titulo completo de um ticket de desenvolvimento: `[EMPRESA] | [SOLICITANTE]
// | [TITULO]`, o mesmo formato do cabecalho do ticket (e de
// Ticket#display_subject no servidor) - pula a parte que o ticket nao tem em
// vez de desenhar colchetes vazios. Ticket importado e' excecao: o titulo ja
// veio pronto da planilha de origem, com empresa dentro, e embrulhar de novo
// duplicaria a informacao.
export const ticketSubject = ticket => {
  if (!ticket) return '';
  if (ticket.custom_attributes?.imported_ticket_number) return ticket.title;

  const requester = ticket.requester_name || ticket.contact?.name;
  return [ticket.company_name, requester, ticket.title]
    .filter(Boolean)
    .map(part => `[${part}]`)
    .join(' | ');
};

export default ticketSubject;
