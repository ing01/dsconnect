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
import { useTicketWorkspace } from '../../composables/useTicketWorkspace';
import TicketWorkspaceTab from './TicketWorkspaceTab.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const { tabs, activeId, hasTabs, restore, openTab, closeTab, applyTicket } =
  useTicketWorkspace();

const currentUser = useMapGetter('getCurrentUser');
const ticketRecords = useMapGetter('tickets/getTicketsList');

const accountId = computed(() => route.params.accountId);
const routeTicketId = computed(() =>
  route.params.ticketId ? Number(route.params.ticketId) : null
);

const strip = ref(null);
// As abas que não cabem na faixa. Elas continuam abertas - só não são
// desenhadas na barra, e estão todas na lista do botão "+".
const hiddenIds = ref([]);
const showAllTabs = ref(false);
// Enquanto mede, tudo é desenhado: medir com aba escondida devolveria a largura
// de uma barra que já foi cortada, e o corte iria encolhendo a cada passada.
const measuring = ref(false);

// Espaço guardado para o próprio botão "+", que também ocupa a faixa.
const OVERFLOW_BUTTON_WIDTH = 60;

const kanbanPath = computed(() =>
  frontendURL(`accounts/${accountId.value}/tickets`)
);
const ticketPath = id =>
  frontendURL(`accounts/${accountId.value}/tickets/${id}`);

const isKanbanActive = computed(() => !routeTicketId.value);

const hiddenCount = computed(() => hiddenIds.value.length);

const isHidden = id => !measuring.value && hiddenIds.value.includes(id);

// O mesmo rótulo da aba, para a lista. Fica aqui, e não no template, porque
// montar texto no meio do HTML é onde ele deixa de ser lido.
const tabLabel = tab =>
  [tab.displayId ? `#${tab.displayId}` : '#…', tab.company, tab.title]
    .filter(Boolean)
    .join(' - ');

// Renaming a Ticket, or moving it to another Empresa, rewrites its tab label as
// soon as the store has the new payload - no refresh, and no request of ours.
const syncLabels = () => (ticketRecords.value || []).forEach(applyTicket);

watch(ticketRecords, syncLabels, { deep: true });

// A new tab starts as a bare number; labelling it from what the store already
// holds spares the user that flash whenever the Ticket has been loaded before.
const openRouteTicket = id => {
  openTab(id);
  syncLabels();
};

// The bar follows the router rather than the click. Every screen that opens a
// Ticket - Kanban, Busca detalhada, Ultimos Tickets, a Conversation, a related
// Ticket - already navigates to its URL, so deriving the tab from the route
// covers all of them at once, and browser back/forward moves between open tabs
// without any of them being torn down.
// Not immediate: the restore below rebuilds the tab list from storage, so
// opening the route's Ticket before it has run would only be undone.
watch(routeTicketId, id => {
  if (id) openRouteTicket(id);
});

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
  // em `hasTabs`), e uma medicao em curso encontraria o ref ja nulo.
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
    visiveis.push(Number(node.dataset.tabId));
  });

  // A aba ativa entra no lugar da última que coube, se tiver ficado de fora.
  const ativa = routeTicketId.value;
  if (ativa && !visiveis.includes(ativa) && visiveis.length) {
    visiveis[visiveis.length - 1] = ativa;
  }

  hiddenIds.value = tabs.value
    .map(tab => tab.id)
    .filter(id => !visiveis.includes(id));
  measuring.value = false;
};

const selectTab = id => {
  showAllTabs.value = false;
  if (id === routeTicketId.value) return;
  router.push(ticketPath(id));
};

// Closing a tab only removes it from this bar. The Ticket keeps its status, and
// nothing is sent to the server.
const onClose = id => {
  const next = closeTab(id);
  // A lista continua aberta ao fechar uma aba por ela: quem abriu para limpar
  // costuma fechar mais de uma, e o painel sumindo a cada clique obrigaria a
  // reabrir toda vez. Fecha sozinha quando não sobra nada.
  if (!tabs.value.length) showAllTabs.value = false;
  if (id !== routeTicketId.value) return;
  router.push(next ? ticketPath(next) : kanbanPath.value);
};

watch([activeId, tabs], measureOverflow, { deep: true });

onMounted(async () => {
  window.addEventListener('resize', measureOverflow);
  await restore(accountId.value, currentUser.value?.id);
  // The route wins over the persisted active id: a direct link must open the
  // Ticket it points at, not the one that happened to be active last session.
  if (routeTicketId.value) openRouteTicket(routeTicketId.value);
  measureOverflow();
});

onBeforeUnmount(() => window.removeEventListener('resize', measureOverflow));
</script>

<template>
  <div
    v-if="hasTabs"
    class="flex items-center w-full min-w-0 gap-2 flex-shrink-0"
  >
    <!-- The Kanban stays one click away, and reaching it closes nothing. -->
    <button
      type="button"
      class="flex items-center flex-shrink-0 h-9 gap-2 px-3 text-sm border rounded-lg transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="
        isKanbanActive
          ? 'border-n-brand bg-n-alpha-2 text-n-slate-12 font-medium'
          : 'border-n-weak bg-n-alpha-black2 text-n-slate-11 hover:border-n-slate-8'
      "
      @click="router.push(kanbanPath)"
    >
      <span class="i-lucide-kanban size-4" />
      {{ t('TICKET.WORKSPACE.KANBAN') }}
    </button>

    <!-- Sem rolagem: o que não cabe não é desenhado aqui, e sim listado no
         botão "+". Uma barra de rolagem obriga a procurar arrastando, e uma aba
         cortada pela metade não se lê. -->
    <div
      ref="strip"
      class="flex items-center flex-1 min-w-0 gap-2 overflow-hidden py-0.5"
    >
      <TicketWorkspaceTab
        v-for="tab in tabs"
        v-show="!isHidden(tab.id)"
        :key="tab.id"
        :tab="tab"
        :is-active="tab.id === routeTicketId"
        :data-active-tab="tab.id === routeTicketId ? 'true' : 'false'"
        :data-tab-id="tab.id"
        @select="selectTab"
        @close="onClose"
      />
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
           um chamado é mais fácil numa lista inteira do que num resto. -->
      <div
        v-if="showAllTabs"
        class="absolute z-50 flex flex-col gap-1 p-1 mt-1 overflow-y-auto border rounded-lg shadow-lg top-full ltr:right-0 rtl:left-0 w-80 max-h-80 border-n-weak bg-n-solid-1"
      >
        <p class="px-2 py-1 m-0 text-xs text-n-slate-10">
          {{ t('TICKET.WORKSPACE.ALL_TABS_COUNT', { count: tabs.length }) }}
        </p>

        <div
          v-for="tab in tabs"
          :key="tab.id"
          class="flex items-center gap-1 rounded-md"
          :class="
            tab.id === routeTicketId ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'
          "
        >
          <button
            type="button"
            class="flex-1 min-w-0 px-2 py-1.5 text-sm text-left truncate focus-visible:outline-none"
            :class="
              tab.id === routeTicketId
                ? 'text-n-slate-12 font-medium'
                : 'text-n-slate-11'
            "
            @click="selectTab(tab.id)"
          >
            {{ tabLabel(tab) }}
          </button>

          <button
            type="button"
            class="flex items-center justify-center flex-shrink-0 rounded size-7 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('TICKET.WORKSPACE.CLOSE_TAB')"
            @click.stop="onClose(tab.id)"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>
      </div>
    </OnClickOutside>
  </div>
</template>
