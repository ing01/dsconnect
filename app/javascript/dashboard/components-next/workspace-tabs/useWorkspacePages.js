import { computed, reactive, shallowRef } from 'vue';
import {
  readPageTabs,
  resolveEntry,
  writePageTabs,
} from './workspacePages';

// As telas abertas na barra de abas (Backlog, Projetos, Chat Interno...). Os
// tickets têm a própria lista - ver useTicketWorkspace - e a barra junta as duas.
//
// O estado fica no escopo do módulo, e não no componente: a barra é montada uma
// vez no layout, mas o estado precisa sobreviver a ela ser remontada (troca de
// conta, paywall) sem reler tudo do localStorage.
const state = reactive({
  scope: null,
  tabs: [],
  activeKey: null,
});

// O catálogo vem do menu lateral (ver Sidebar.vue) e muda com ele: um time
// criado agora vira uma tela que pode ter aba.
const catalog = shallowRef([]);

const persist = () => {
  if (!state.scope) return;
  const [accountId, userId] = state.scope;
  writePageTabs(accountId, userId, state.tabs);
};

export function useWorkspacePages() {
  const tabs = computed(() => state.tabs);
  const activeKey = computed(() => state.activeKey);

  // O menu se recalcula a cada contador de não lidas que muda; trocar o catálogo
  // por um igual refaria a leitura da rota (e a gravação das abas) à toa.
  const signature = entries =>
    entries.map(entry => `${entry.key}|${entry.label}|${entry.icon}`).join('\n');

  const setCatalog = entries => {
    if (signature(entries) === signature(catalog.value)) return;
    catalog.value = entries;
  };

  // Relê as abas guardadas na primeira vez que vê esta (conta, usuário).
  const restore = (accountId, userId) => {
    const scope = [Number(accountId), Number(userId)];
    if (state.scope?.[0] === scope[0] && state.scope?.[1] === scope[1]) return;

    state.scope = scope;
    state.tabs = readPageTabs(accountId, userId);
    state.activeKey = null;
  };

  // Acompanha a rota: toda tela que é item do menu ganha aba na primeira visita,
  // e a aba lembra o caminho mais recente dentro dela - voltar para "Contatos"
  // devolve a página e a busca em que se estava. O detalhe de um ticket não
  // passa por aqui: ele tem a própria aba.
  const syncRoute = route => {
    if (route.params?.ticketId || route.name === 'ticket_detail') {
      state.activeKey = null;
      return;
    }

    const entry = resolveEntry(catalog.value, route);
    if (!entry) {
      state.activeKey = null;
      return;
    }

    const next = {
      key: entry.key,
      label: entry.label,
      icon: entry.icon,
      path: route.fullPath,
    };
    const index = state.tabs.findIndex(tab => tab.key === entry.key);
    if (index === -1) {
      state.tabs.push(next);
    } else {
      state.tabs.splice(index, 1, next);
    }
    state.activeKey = entry.key;
    persist();
  };

  // Rótulo e ícone vêm do menu quando ele já os conhece (e acompanham o idioma);
  // o guardado só cobre o intervalo até o menu carregar.
  const describe = tab => {
    const entry = catalog.value.find(item => item.key === tab.key);
    return { ...tab, label: entry?.label || tab.label, icon: entry?.icon || tab.icon };
  };

  const closePage = key => {
    state.tabs = state.tabs.filter(tab => tab.key !== key);
    if (state.activeKey === key) state.activeKey = null;
    persist();
  };

  return {
    tabs,
    activeKey,
    catalog,
    setCatalog,
    restore,
    syncRoute,
    describe,
    closePage,
  };
}
