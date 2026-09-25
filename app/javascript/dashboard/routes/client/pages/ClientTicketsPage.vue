<script setup>
/**
 * Os chamados do cliente, em LISTA ou em Kanban.
 *
 * As duas visões são os componentes reais do painel - `TicketListView` e
 * `TicketBoard` -> `TicketBoardColumn` -> `TicketCard` -, com o mesmo cabeçalho:
 * seletor de Mesa, busca rápida e ordenação. Não há cópia visual nenhuma aqui;
 * o que muda é a origem dos dados (a API do cliente, já recortada pela empresa
 * dele), o modo `read-only`, que tira do quadro as ações do atendimento, e a
 * ausência do filtro por responsável, que é escolha de quem atende.
 *
 * UMA carga alimenta as duas: o botão troca a forma de ler, e não o conjunto
 * lido. Buscar de novo ao alternar deixaria a lista e o quadro discordando
 * sobre quantos chamados existem.
 *
 * Quando o painel mudar, esta tela muda junto - que é o motivo de ela não ter
 * componentes próprios.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import {
  getClientSession,
  getTicketsView,
  setTicketsView,
} from 'dashboard/helper/clientSession';
import {
  readSortPreference,
  writeSortPreference,
} from 'dashboard/routes/dashboard/tickets/helpers/ticketSort';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketBoard from 'dashboard/routes/dashboard/tickets/components/TicketBoard.vue';
import TicketListView from 'dashboard/routes/dashboard/tickets/components/TicketListView.vue';
import { ticketMatchesFilters } from 'dashboard/routes/dashboard/tickets/helpers/ticketFilters';
import TicketMesaSelector from 'dashboard/routes/dashboard/tickets/components/TicketMesaSelector.vue';
import TicketSortMenu from 'dashboard/routes/dashboard/tickets/components/TicketSortMenu.vue';
import ClientTicketDialog from '../components/ClientTicketDialog.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const board = ref({ teams: [], ticket_columns: [], id: null });
const categorias = ref([]);
const selectedTeamId = ref(null);
const quickSearch = ref('');
const sort = ref(null);
const novoTicketDialog = ref(null);
// Lista por padrão: foi o que pediram como visão principal. O Kanban continua
// inteiro, a um clique.
const visao = ref(getTicketsView());

const contact = computed(() => getClientSession()?.contact || {});
const accountId = computed(() => contact.value.account_id);
const teams = computed(() => board.value.teams || []);

// A busca rápida, aplicada sobre o quadro já carregado - o mesmo caminho do
// Kanban interno. Não há filtro por responsável: quem atende é assunto da
// equipe, e o cliente não escolhe por isso.
const filters = computed(() => ({ query: quickSearch.value }));

// Os responsáveis que aparecem nos chamados DELE - e não o quadro de agentes da
// conta, que não é informação do cliente.
//
// Continua existindo mesmo sem o filtro por agente: é desta lista que o cartão
// do Kanban tira o NOME de quem atende (vide `assigneeName` em TicketCard).
const mesaAgents = computed(() => {
  const vistos = new Map();
  (board.value.ticket_columns || []).forEach(column =>
    (column.tickets || []).forEach(ticket => {
      if (ticket.assignee_id && !vistos.has(ticket.assignee_id)) {
        vistos.set(ticket.assignee_id, {
          id: ticket.assignee_id,
          name: ticket.assignee_name,
          thumbnail: ticket.assignee_thumbnail,
        });
      }
    })
  );
  return [...vistos.values()];
});

// Os grupos da lista: um por Estágio, na ORDEM da Mesa, com os mesmos chamados
// do quadro passados pelo MESMO filtro que as colunas aplicam.
//
// Separado por Estágio de propósito, e não achatado: é assim que o cliente
// acompanha o andamento, e cada grupo pode ser recolhido para tirar da frente o
// que ele não quer ver. A `TicketListView` guarda o que está recolhido.
const grupos = computed(() =>
  (board.value.ticket_columns || []).map(column => ({
    id: column.id,
    name: column.name,
    rows: (column.tickets || []).filter(ticket =>
      ticketMatchesFilters(ticket, filters.value)
    ),
  }))
);

const trocarVisao = escolhida => {
  visao.value = escolhida;
  setTicketsView(escolhida);
};

const carregar = async (teamId = null) => {
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.board(teamId);
    board.value = data;
    selectedTeamId.value = data.id;
    sort.value = readSortPreference(accountId.value, data.id);
  } catch {
    useAlert(t('CLIENT_AREA.BOARD.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const selectTeam = teamId => {
  selectedTeamId.value = Number(teamId);
  carregar(Number(teamId));
};

const updateSort = novaOrdem => {
  sort.value = novaOrdem;
  writeSortPreference(accountId.value, selectedTeamId.value, novaOrdem);
};

const abrirTicket = ticket => {
  router.push({
    name: 'client_ticket_detail',
    params: { ticketId: ticket.id },
  });
};

const abrirNovoTicket = async () => {
  if (!categorias.value.length) {
    const { data } = await ClientAreaAPI.categories();
    categorias.value = data;
  }
  novoTicketDialog.value?.open();
};

// Depois de abrir, o quadro é relido: o chamado novo precisa aparecer onde a
// Mesa o colocou, e não onde a tela imaginaria.
const aoCriar = () => {
  carregar(selectedTeamId.value);
};

onMounted(() => carregar());
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 min-w-0 gap-4 p-4">
    <header class="flex flex-col flex-shrink-0 w-full gap-3 min-w-0">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('TICKET.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('CLIENT_AREA.BOARD.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex flex-wrap items-center w-full gap-3 min-w-0">
        <TicketMesaSelector
          v-if="teams.length"
          :teams="teams"
          :selected-team-id="selectedTeamId"
          @select="selectTeam"
        />

        <!-- Lista ou Kanban. Os dois botões juntos, como um seletor: são duas
             formas de ler o MESMO conjunto, e não duas telas. -->
        <div
          v-if="selectedTeamId"
          class="flex flex-shrink-0 gap-1 p-1 border rounded-lg border-n-weak bg-n-alpha-black2"
          role="group"
          :aria-label="t('CLIENT_AREA.BOARD.VIEW.LABEL')"
        >
          <button
            v-for="opcao in ['list', 'kanban']"
            :key="opcao"
            type="button"
            class="flex items-center gap-1.5 px-2.5 py-1 text-sm rounded-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="
              visao === opcao
                ? 'bg-n-solid-1 text-n-slate-12 font-medium shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            :aria-pressed="visao === opcao"
            @click="trocarVisao(opcao)"
          >
            <Icon
              :icon="opcao === 'list' ? 'i-lucide-list' : 'i-lucide-kanban'"
              class="size-4"
            />
            {{ t(`CLIENT_AREA.BOARD.VIEW.${opcao.toUpperCase()}`) }}
          </button>
        </div>

        <NextInput
          v-if="selectedTeamId"
          v-model="quickSearch"
          type="search"
          size="sm"
          class="group w-56 min-w-0 flex-shrink-0 ltr:ml-auto rtl:mr-auto [&>input]:ltr:!pl-8 [&>input]:rtl:!pr-8 [&>input]:!rounded-[0.625rem]"
          :placeholder="t('TICKET.SEARCH.QUICK_PLACEHOLDER')"
          :aria-label="t('TICKET.SEARCH.QUICK_PLACEHOLDER')"
        >
          <template #prefix>
            <Icon
              icon="i-lucide-search"
              class="absolute top-1/2 -translate-y-1/2 text-n-slate-11 group-focus-within:text-n-brand size-3.5 ltr:left-2.5 rtl:right-2.5"
            />
          </template>
        </NextInput>

        <!-- A ordenação do cabeçalho é do quadro: nele cada Estágio é uma
             pilha própria. Na lista, quem ordena é o cabeçalho da tabela. -->
        <TicketSortMenu
          v-if="selectedTeamId && visao === 'kanban'"
          :sort="sort"
          @update="updateSort"
        />

        <NextButton
          icon="i-lucide-plus"
          size="sm"
          class="flex-shrink-0"
          :label="t('CLIENT_AREA.BOARD.NEW_TICKET')"
          @click="abrirNovoTicket"
        />
      </div>
    </header>

    <div
      v-if="isLoading"
      class="flex justify-center flex-1 py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <div
      v-else-if="!board.ticket_columns.length"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <Icon icon="i-lucide-inbox" class="size-6 text-n-slate-10" />
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('CLIENT_AREA.BOARD.EMPTY') }}
      </p>
    </div>

    <TicketListView
      v-else-if="visao === 'list'"
      :filters="filters"
      :groups="grupos"
      :account-id="accountId"
      :team-id="selectedTeamId"
      :loading="isLoading"
      @open-ticket="abrirTicket"
    />

    <TicketBoard
      v-else
      :board="board"
      :account-id="accountId"
      :team-id="selectedTeamId"
      :agents="mesaAgents"
      :filters="filters"
      :sort="sort"
      read-only
      @open-ticket="abrirTicket"
    />

    <ClientTicketDialog
      ref="novoTicketDialog"
      :categories="categorias"
      @created="aoCriar"
    />
  </div>
</template>
