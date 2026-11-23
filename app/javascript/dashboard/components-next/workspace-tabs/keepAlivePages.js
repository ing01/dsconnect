// As telas que ficam VIVAS (montadas, so' escondidas) quando a pessoa troca de aba. Sem isso, cada
// troca destruia a tela e o que foi feito nela - filtros, busca, rolagem - se perdia ao voltar.
//
// Entram so' telas que nao dependem da rota para se atualizar: uma tela que escuta a rota continuaria
// reagindo as mudancas de rota enquanto escondida. Por isso ficam de fora, por enquanto, as Conversas
// (a tela escuta a rota), o Chat interno, as Sugestoes e os Contratos.
//
// Os nomes sao os dos componentes (o `include` do KeepAlive casa pelo nome; em <script setup> o nome
// e' o do arquivo). `TicketsWorkspaceRouteView` guarda o modulo de Tickets inteiro, e o Kanban
// continua com o proprio KeepAlive la dentro.
export const KEEP_ALIVE_PAGES = [
  'TicketsWorkspaceRouteView',
  'ProjectsPage',
  'ImplementationReportsPage',
  'AgendaPage',
  'CrmClientsPage',
  'CrmSalesPage',
  'CrmDashboardPage',
];

// Teto de telas guardadas ao mesmo tempo: as mais antigas sao descartadas primeiro.
export const KEEP_ALIVE_MAX = 10;
