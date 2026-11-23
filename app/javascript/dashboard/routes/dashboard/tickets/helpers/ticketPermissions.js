// Cancelar um ticket e' do administrador e de quem recebeu a permissao `ticket_cancel` numa funcao
// personalizada (o servidor recusa o resto). `permissions` e' a lista da conta da pessoa logada.
export const CANCEL_PERMISSION = 'ticket_cancel';

export const canCancelTickets = (role, permissions = []) =>
  role === 'administrator' || (permissions || []).includes(CANCEL_PERMISSION);
