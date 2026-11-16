import { useTicketWorkspace } from '../composables/useTicketWorkspace';

// Ctrl (ou Cmd no Mac) + clique num card abre o ticket numa ABA INTERNA do
// workspace (a barra de abas do DSConnect) sem sair da tela atual: a pessoa
// segue no Kanban e vai juntando os tickets nas abas para ler depois.
export const wantsWorkspaceTab = event =>
  Boolean(event?.ctrlKey || event?.metaKey);

// Devolve true quando só abriu a aba (quem chamou não navega).
export const openInWorkspaceTab = (ticket, event) => {
  if (!wantsWorkspaceTab(event)) return false;
  // `activate: false`: a aba entra na barra, mas a tela e a aba ativa ficam.
  useTicketWorkspace().openTab(ticket, { activate: false });
  return true;
};
