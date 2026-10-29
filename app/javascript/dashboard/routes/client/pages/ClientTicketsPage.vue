<script setup>
/**
 * Os chamados do cliente, numa lista unica - todas as Mesas juntas, e nao
 * uma por vez. Antes era preciso trocar de Mesa para ver cada conjunto de
 * chamados; agora a lista inteira aparece de uma vez, e cada linha traz a
 * Mesa e o Estagio onde o chamado esta (`team_name`/`ticket_column_name`,
 * colunas MESA/ESTAGIO da `TicketListView`).
 *
 * A visao e a mesma `TicketListView` do painel interno, sem cópia visual - o
 * que muda e a origem dos dados (a API do cliente, já recortada pela empresa
 * dele) e a ausência do filtro por responsável, que é escolha de quem
 * atende. Sem agrupamento por Estagio aqui: Mesas diferentes tem Estagios
 * com nomes proprios, e juntar colunas que nao significam a mesma coisa
 * bagunçaria a leitura - por isso um grupo so, sem cabecalho (ver `grupos`).
 *
 * Quando o painel mudar, esta tela muda junto - que é o motivo de ela não ter
 * componentes próprios.
 */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ClientAreaAPI from 'dashboard/api/clientArea';
import { getClientSession } from 'dashboard/helper/clientSession';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketListView from 'dashboard/routes/dashboard/tickets/components/TicketListView.vue';
import { ticketMatchesFilters } from 'dashboard/routes/dashboard/tickets/helpers/ticketFilters';
import ClientTicketDialog from '../components/ClientTicketDialog.vue';
import ClientTicketFilters from '../components/ClientTicketFilters.vue';

const { t } = useI18n();
const router = useRouter();

const isLoading = ref(true);
const board = ref({
  companies: [],
  teams: [],
  ticket_columns: [],
  assignees: [],
  tickets: [],
});
const categorias = ref([]);
const selectedCompanyId = ref(null);
const quickSearch = ref('');

// Os filtros que o servidor aplica (Mesa, Estagio, Responsavel, status e periodo
// de abertura) - os mesmos do app. A busca rapida abaixo e' a unica que roda no
// navegador, em cima do que ja chegou.
const emptyFilters = () => ({
  teamId: null,
  ticketColumnId: null,
  assigneeId: null,
  status: null,
  createdAfter: null,
  createdBefore: null,
});
const serverFilters = ref(emptyFilters());
const hasServerFilters = computed(() =>
  Object.values(serverFilters.value).some(valor => valor !== null)
);
const novoTicketDialog = ref(null);

const contact = computed(() => getClientSession()?.contact || {});
const accountId = computed(() => contact.value.account_id);
// So faz sentido mostrar o filtro quando ha o que filtrar - um contato com
// uma unica Empresa ja ve so os tickets dela, sem escolha nenhuma.
const companies = computed(() => board.value.companies || []);
const showCompanyFilter = computed(() => companies.value.length > 1);

// A busca rápida, aplicada sobre a lista já carregada.
const filters = computed(() => ({ query: quickSearch.value }));

// Um grupo so, sem nome - a `TicketListView` sabe nao desenhar cabecalho de
// Estagio quando o grupo nao tem nome (ver o componente), e e exatamente o
// que se quer aqui: uma lista unica, sem divisao por Mesa nem por Estagio.
const grupos = computed(() => [
  {
    id: 'all',
    name: '',
    rows: (board.value.tickets || []).filter(ticket =>
      ticketMatchesFilters(ticket, filters.value)
    ),
  },
]);

// Cada mudanca de filtro refaz o pedido; uma resposta antiga que chega depois
// de uma mais nova (filtro trocado rapido) nao pode sobrescrever a lista.
let ultimoPedido = 0;

const carregar = async () => {
  ultimoPedido += 1;
  const pedido = ultimoPedido;
  isLoading.value = true;
  try {
    const { data } = await ClientAreaAPI.board(
      selectedCompanyId.value,
      serverFilters.value
    );
    if (pedido === ultimoPedido) board.value = data;
  } catch {
    if (pedido === ultimoPedido) useAlert(t('CLIENT_AREA.BOARD.ERROR'));
  } finally {
    if (pedido === ultimoPedido) isLoading.value = false;
  }
};

watch(serverFilters, carregar);

const limparFiltros = () => {
  serverFilters.value = emptyFilters();
};

const selectCompany = event => {
  const valor = event.target.value;
  selectedCompanyId.value = valor ? Number(valor) : null;
  carregar();
};

const abrirTicket = ticket => {
  router.push({
    name: 'client_ticket_detail',
    params: { ticketId: ticket.id },
  });
};

// A lista e' relida a cada abertura: a Categoria pode ter sido marcada ou
// desmarcada para o Portal depois que a tela carregou, e o rascunho por IA
// consulta o servidor de novo - uma lista velha faria o botao aparecer e o
// servidor responder `no_categories`.
const abrirNovoTicket = async () => {
  try {
    const { data } = await ClientAreaAPI.categories();
    categorias.value = data;
  } catch {
    categorias.value = [];
  }
  novoTicketDialog.value?.open();
};

// Depois de abrir, a lista é relida: o chamado novo precisa aparecer.
const aoCriar = () => carregar();

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
        <select
          v-if="showCompanyFilter"
          :value="selectedCompanyId ?? ''"
          class="flex-shrink-0 h-8 px-2 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12 max-w-48"
          :aria-label="t('CLIENT_AREA.BOARD.COMPANY_FILTER')"
          @change="selectCompany"
        >
          <option value="">{{ t('CLIENT_AREA.BOARD.ALL_COMPANIES') }}</option>
          <option
            v-for="empresa in companies"
            :key="empresa.id"
            :value="empresa.id"
          >
            {{ empresa.name }}
          </option>
        </select>

        <NextInput
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

        <NextButton
          icon="i-lucide-plus"
          size="sm"
          class="flex-shrink-0"
          :label="t('CLIENT_AREA.BOARD.NEW_TICKET')"
          @click="abrirNovoTicket"
        />
      </div>

      <ClientTicketFilters
        v-model="serverFilters"
        :teams="board.teams"
        :ticket-columns="board.ticket_columns"
        :assignees="board.assignees"
        @clear="limparFiltros"
      />
    </header>

    <div
      v-if="isLoading"
      class="flex justify-center flex-1 py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <div
      v-else-if="!board.tickets.length"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <Icon icon="i-lucide-inbox" class="size-6 text-n-slate-10" />
      <p class="m-0 text-sm text-n-slate-11">
        {{
          hasServerFilters
            ? t('CLIENT_AREA.BOARD.FILTERS.NO_MATCH')
            : t('CLIENT_AREA.BOARD.EMPTY')
        }}
      </p>
    </div>

    <TicketListView
      v-else
      :filters="filters"
      :groups="grupos"
      :account-id="accountId"
      :loading="isLoading"
      complexity-column="due_date"
      @open-ticket="abrirTicket"
    />

    <ClientTicketDialog
      ref="novoTicketDialog"
      :categories="categorias"
      @created="aoCriar"
    />
  </div>
</template>
