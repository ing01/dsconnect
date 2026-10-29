<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { OnClickOutside } from '@vueuse/components';
import { useTicketWorkspace } from 'dashboard/routes/dashboard/tickets/composables/useTicketWorkspace';
import TicketWorkspaceTab from 'dashboard/routes/dashboard/tickets/components/workspace/TicketWorkspaceTab.vue';
import WorkspacePageTab from './WorkspacePageTab.vue';
import { useWorkspacePages } from './useWorkspacePages';
import { neighbourItem, PRINCIPAL_KEY_PREFIX } from './workspacePages';

// A barra de abas do sistema todo: as telas abertas pelo menu (Kanban, Backlog,
// Projetos, Chat Interno...) e os tickets abertos, lado a lado. Fica no layout,
// acima da página, então trocar de tela é uma troca de rota comum e nenhuma
// aba some.
//
// Fechar uma aba é só uma ação de tela: nenhum pedido ao servidor, nenhuma
// marca no ticket.
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const {
  tabs: ticketTabs,
  restore: restoreTickets,
  openTab,
  closeTab: closeTicketTab,
  applyTicket,
} = useTicketWorkspace();

const {
  tabs: pageTabs,
  activeKey,
  catalog,
  restore: restorePages,
  syncRoute,
  describe,
  closePage,
} = useWorkspacePages();

const currentUser = useMapGetter('getCurrentUser');
const ticketRecords = useMapGetter('tickets/getTicketsList');

const accountId = computed(() => route.params.accountId);
const routeTicketId = computed(() =>
  route.params.ticketId ? Number(route.params.ticketId) : null
);

const strip = ref(null);
// As abas que não cabem na faixa. Continuam abertas - só não são desenhadas na
// barra, e estão todas na lista do botão "+".
const hiddenIds = ref([]);
const showAllTabs = ref(false);
// Enquanto mede, tudo é desenhado: medir com aba escondida devolveria a largura
// de uma barra que já foi cortada, e o corte iria encolhendo a cada passada.
const measuring = ref(false);

// Espaço guardado para o próprio botão "+", que também ocupa a faixa.
const OVERFLOW_BUTTON_WIDTH = 60;

const ticketPath = id =>
  frontendURL(`accounts/${accountId.value}/tickets/${id}`);

// Telas primeiro, tickets depois: o que se abre pelo menu fica num lugar
// previsível, e os tickets - que vêm e vão o dia todo - crescem no fim.
const items = computed(() => [
  ...pageTabs.value.map(tab => ({
    type: 'page',
    id: `page:${tab.key}`,
    tab: describe(tab),
  })),
  ...ticketTabs.value.map(tab => ({
    type: 'ticket',
    id: `ticket:${tab.id}`,
    tab,
  })),
]);

const hasItems = computed(() => items.value.length > 0);

const isActive = item =>
  item.type === 'ticket'
    ? item.tab.id === routeTicketId.value
    : !routeTicketId.value && item.tab.key === activeKey.value;

// A tela Principal é o destino de quando não sobra aba nenhuma: fechá-la sendo a
// única só faria ela reaparecer, então o botão nem é oferecido.
const isClosable = item =>
  !(
    items.value.length === 1 &&
    item.type === 'page' &&
    item.tab.key.startsWith(PRINCIPAL_KEY_PREFIX)
  );

const hiddenCount = computed(() => hiddenIds.value.length);
const isHidden = id => !measuring.value && hiddenIds.value.includes(id);

// O mesmo rótulo da aba, para a lista. Fica aqui, e não no template, porque
// montar texto no meio do HTML é onde ele deixa de ser lido.
const itemLabel = item =>
  item.type === 'page'
    ? item.tab.label
    : [
        item.tab.displayId ? `#${item.tab.displayId}` : '#…',
        item.tab.company,
        item.tab.title,
      ]
        .filter(Boolean)
        .join(' - ');

// Renomear um ticket, ou movê-lo para outra Empresa, reescreve o rótulo da aba
// assim que a store tem o dado novo - sem recarregar e sem pedido nosso.
const syncLabels = () => (ticketRecords.value || []).forEach(applyTicket);

watch(ticketRecords, syncLabels, { deep: true });

const openRouteTicket = id => {
  openTab(id);
  syncLabels();
};

// A barra segue o roteador, e não o clique. Toda tela que abre um ticket ou uma
// página já navega para a URL dela, então derivar a aba da rota cobre todas de
// uma vez, e o voltar/avançar do navegador anda entre as abas abertas.
watch(routeTicketId, id => {
  if (id) openRouteTicket(id);
});

// Também quando o menu muda: um time criado agora, ou a lista de marcadores que
// terminou de carregar, torna reconhecível a tela em que a pessoa já está.
watch([() => route.fullPath, catalog], () => syncRoute(route));

/**
 * Decide quais abas cabem na faixa.
 *
 * Mede com todas desenhadas, corta a partir da primeira que estoura, e garante
 * que a aba ATIVA fique sempre à vista - esconder justamente a que se está
 * lendo seria o pior resultado possível.
 */
const measureOverflow = async () => {
  if (!strip.value) return;

  measuring.value = true;
  await nextTick();

  // Relido DEPOIS da espera: fechar a ultima aba tira a barra do DOM (`v-if`
  // em `hasItems`), e uma medicao em curso encontraria o ref ja nulo.
  const faixa = strip.value;
  if (!faixa) {
    measuring.value = false;
    return;
  }

  // Largura zero significa que a barra ainda nao foi desenhada (aba de fundo,
  // container escondido). Medir ali esconderia TUDO e mostraria o "+" com o
  // total - melhor nao mexer e remedir quando ela aparecer.
  if (!faixa.clientWidth) {
    measuring.value = false;
    return;
  }

  const nodes = [...faixa.querySelectorAll('[data-tab-id]')];
  const total = nodes.reduce((soma, node) => soma + node.offsetWidth, 0);
  const espacamento = Math.max(0, nodes.length - 1) * 8;

  // Tudo cabe: nada a esconder, e o botão "+" não aparece.
  if (total + espacamento <= faixa.clientWidth) {
    hiddenIds.value = [];
    measuring.value = false;
    return;
  }

  const disponivel = faixa.clientWidth - OVERFLOW_BUTTON_WIDTH;
  const visiveis = [];
  let usado = 0;

  nodes.forEach(node => {
    const largura = node.offsetWidth + (visiveis.length ? 8 : 0);
    if (usado + largura > disponivel) return;
    usado += largura;
    visiveis.push(node.dataset.tabId);
  });

  // A aba ativa entra no lugar da última que coube, se tiver ficado de fora.
  const ativa = items.value.find(isActive)?.id;
  if (ativa && !visiveis.includes(ativa) && visiveis.length) {
    visiveis[visiveis.length - 1] = ativa;
  }

  hiddenIds.value = items.value
    .map(item => item.id)
    .filter(id => !visiveis.includes(id));
  measuring.value = false;
};

const goTo = item => {
  router.push(item.type === 'page' ? item.tab.path : ticketPath(item.tab.id));
};

const selectItem = item => {
  showAllTabs.value = false;
  if (isActive(item)) return;
  goTo(item);
};

const goToPrincipal = () =>
  router.push({ name: 'principal', params: { accountId: accountId.value } });

const closeItem = item => {
  // Calculado ANTES de remover: depois, a vizinha já não é encontrada.
  const next = neighbourItem(items.value, item.id);
  const wasActive = isActive(item);

  if (item.type === 'page') closePage(item.tab.key);
  else closeTicketTab(item.tab.id);

  // A lista continua aberta ao fechar uma aba por ela: quem abriu para limpar
  // costuma fechar mais de uma, e o painel sumindo a cada clique obrigaria a
  // reabrir toda vez. Fecha sozinha quando não sobra nada.
  if (items.value.length === 0) showAllTabs.value = false;
  if (!wasActive) return;

  if (next) goTo(next);
  else goToPrincipal();
};

watch([items, () => route.fullPath], measureOverflow);

onMounted(async () => {
  window.addEventListener('resize', measureOverflow);
  restorePages(accountId.value, currentUser.value?.id);
  syncRoute(route);
  await restoreTickets(accountId.value, currentUser.value?.id);
  // A rota vence o que foi guardado: um link direto abre o ticket para o qual
  // aponta, e não o que estava ativo da última vez.
  if (routeTicketId.value) openRouteTicket(routeTicketId.value);
  measureOverflow();
});

onBeforeUnmount(() => window.removeEventListener('resize', measureOverflow));
</script>

<template>
  <div
    v-if="hasItems"
    class="flex items-center w-full min-w-0 gap-2 px-4 pt-3 pb-1 flex-shrink-0"
  >
    <!-- Sem rolagem: o que não cabe não é desenhado aqui, e sim listado no
         botão "+". Uma barra de rolagem obriga a procurar arrastando, e uma aba
         cortada pela metade não se lê. -->
    <div
      ref="strip"
      class="flex items-center flex-1 min-w-0 gap-2 overflow-hidden py-0.5"
    >
      <template v-for="item in items" :key="item.id">
        <WorkspacePageTab
          v-if="item.type === 'page'"
          v-show="!isHidden(item.id)"
          :tab="item.tab"
          :is-active="isActive(item)"
          :closable="isClosable(item)"
          :data-active-tab="isActive(item) ? 'true' : 'false'"
          :data-tab-id="item.id"
          @select="selectItem(item)"
          @close="closeItem(item)"
        />
        <TicketWorkspaceTab
          v-else
          v-show="!isHidden(item.id)"
          :tab="item.tab"
          :is-active="isActive(item)"
          :data-active-tab="isActive(item) ? 'true' : 'false'"
          :data-tab-id="item.id"
          @select="selectItem(item)"
          @close="closeItem(item)"
        />
      </template>
    </div>

    <OnClickOutside
      v-if="hiddenCount > 0"
      class="relative flex-shrink-0"
      @trigger="showAllTabs = false"
    >
      <button
        type="button"
        class="flex items-center justify-center h-9 gap-1 px-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-11 hover:border-n-slate-8 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-expanded="showAllTabs"
        :aria-label="t('TICKET.WORKSPACE.ALL_TABS')"
        :title="t('TICKET.WORKSPACE.ALL_TABS')"
        @click="showAllTabs = !showAllTabs"
      >
        <span class="i-lucide-plus size-4" />
        {{ hiddenCount }}
      </button>

      <!-- A lista traz TODAS as abas abertas, e não só as escondidas: procurar
           uma aba é mais fácil numa lista inteira do que num resto. -->
      <div
        v-if="showAllTabs"
        class="absolute z-50 flex flex-col gap-1 p-1 mt-1 overflow-y-auto border rounded-lg shadow-lg top-full ltr:right-0 rtl:left-0 w-80 max-h-80 border-n-weak bg-n-solid-1"
      >
        <p class="px-2 py-1 m-0 text-xs text-n-slate-10">
          {{ t('TICKET.WORKSPACE.ALL_TABS_COUNT', { count: items.length }) }}
        </p>

        <div
          v-for="item in items"
          :key="item.id"
          class="flex items-center gap-1 rounded-md"
          :class="isActive(item) ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'"
        >
          <button
            type="button"
            class="flex-1 min-w-0 px-2 py-1.5 text-sm text-left truncate focus-visible:outline-none"
            :class="
              isActive(item)
                ? 'text-n-slate-12 font-medium'
                : 'text-n-slate-11'
            "
            @click="selectItem(item)"
          >
            {{ itemLabel(item) }}
          </button>

          <button
            v-if="isClosable(item)"
            type="button"
            class="flex items-center justify-center flex-shrink-0 rounded size-7 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('TICKET.WORKSPACE.CLOSE_TAB')"
            @click.stop="closeItem(item)"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>
      </div>
    </OnClickOutside>
  </div>
</template>
