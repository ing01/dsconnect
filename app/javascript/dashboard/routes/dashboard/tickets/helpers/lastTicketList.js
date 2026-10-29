import { ref } from 'vue';

// As telas de lista do módulo: de qualquer uma delas se abre um ticket, e o
// "Voltar" do ticket deve devolver a pessoa para a MESMA tela (e com os mesmos
// filtros), não sempre para o Kanban.
const LIST_ROUTE_NAMES = ['tickets_index', 'tickets_backlog', 'tickets_triage'];

// Fica fora do componente de propósito: a página do ticket é montada e
// desmontada a cada navegação, e este valor precisa sobreviver a isso.
const lastListPath = ref(null);

export const rememberTicketList = route => {
  if (LIST_ROUTE_NAMES.includes(route.name)) {
    lastListPath.value = route.fullPath;
  }
};

// Só vale para a conta atual: o caminho guardado carrega o id dela.
export const lastTicketListFor = accountId => {
  const path = lastListPath.value;
  return path && path.includes(`/accounts/${accountId}/`) ? path : null;
};
