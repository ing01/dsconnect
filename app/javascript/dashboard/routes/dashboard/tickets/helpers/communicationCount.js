// O numero ao lado de "Comunicacao": comentarios internos + mensagens do cliente.
//
// Os internos vem do servidor (`internal_comments_count`), para o numero aparecer
// sem abrir a aba. Depois que a aba foi aberta, a lista de comentarios fica na
// store e passa a mandar: assim comentar ou apagar atualiza o numero na hora,
// sem reler o ticket. As mensagens ao cliente ja vem no proprio ticket.
export const communicationCount = (ticket, storedComments) => {
  if (!ticket) return 0;

  const internal = Array.isArray(storedComments)
    ? storedComments.length
    : Number(ticket.internal_comments_count) || 0;
  const customer = (ticket.customer_communications || []).length;

  return internal + customer;
};
