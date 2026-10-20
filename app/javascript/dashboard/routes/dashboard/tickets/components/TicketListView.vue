<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { toSearchParams } from '../helpers/ticketSearchParams';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { frontendURL } from 'dashboard/helper/URLHelper';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  readColumnPreferences,
  toggleColumnHidden,
  setColumnWidth,
} from '../helpers/ticketListColumns';

// `filters` is the flat, camelCase state owned by TicketDetailedSearchModal
// (the "Busca detalhada" panel) - this component only turns it into
// backend query params and renders the resulting page of results.
//
// `groups` inverte essa origem. Quando vem preenchido, a lista desenha o que lhe
// entregaram - ja separado por Estagio - e NAO fala com o store: e o caminho da
// Area do Cliente, que tem API propria e ja carregou os chamados para o Kanban.
// Buscar de novo criaria uma segunda verdade: a lista poderia mostrar um
// conjunto diferente do quadro ao lado, com o mesmo botao alternando entre os
// dois.
//
// Cada grupo e `{ id, name, rows }`. Vem pronto, e nao agrupado aqui, porque a
// ORDEM dos Estagios e a da Mesa (`position`) - reagrupar por nome acabaria
// alfabetico, com "Aguardando" antes de "Pendente".
const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
  groups: { type: Array, default: null },
  loading: { type: Boolean, default: false },
  // So no modo `groups`: e a chave de onde fica guardado o que esta recolhido.
  accountId: { type: [Number, String], default: null },
  teamId: { type: [Number, String], default: null },
  // A Area do Cliente troca a ultima coluna: em vez de Complexidade, ela mostra
  // o Prazo (due_date) - o Kanban/lista interna dos atendentes continua vendo
  // Complexidade, entao o default preserva o comportamento de sempre.
  complexityColumn: {
    type: String,
    default: 'complexity',
    validator: value => ['complexity', 'due_date'].includes(value),
  },
});

// Quem abre o ticket muda com a origem: no painel e a rota interna; com
// `groups`, quem entregou os dados e quem sabe para onde ir.
const emit = defineEmits(['openTicket']);
import { statusColor } from '../helpers/ticketLabels';
import { sortTickets } from '../helpers/ticketSort';
import {
  readCollapsedColumnIds,
  toggleCollapsedColumn,
} from '../helpers/collapsedColumns';

// Recolher um Estagio AQUI nao pode recolher a coluna no Kanban: sao duas
// formas de ler o mesmo quadro, e quem esconde "Concluido" da lista pode muito
// bem querer ve-lo no quadro.
const COLLAPSE_SCOPE = 'list';

const PER_PAGE = 25;

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');

// A lista foi entregue pronta? Decide TUDO abaixo: origem das linhas, quem
// ordena, se ha paginacao e se o store e consultado.
const recebeLinhas = computed(() => props.groups !== null);

const uiFlags = computed(() => store.getters['tickets/getUIFlags']);

// Cada cabecalho e a chave que o servidor entende (Tickets::SearchOrdering).
// A ordenacao vai para o servidor porque a lista e paginada la: ordenar so as
// linhas carregadas mostraria o menor valor DESTA pagina, e nao do resultado.
// A ultima coluna muda de identidade conforme `complexityColumn` - o `key`
// precisa mudar junto (nao so o `label`), senao a celula abaixo nao saberia
// qual das duas mostrar.
const LAST_COLUMN = {
  complexity: { key: 'ticket_complexity', label: 'COMPLEXITY' },
  due_date: { key: 'ticket_due_date', label: 'DUE_DATE' },
};

const COLUMNS = computed(() => [
  { key: 'display_id', label: 'ID' },
  { key: 'created_at', label: 'CREATED_AT' },
  { key: 'title', label: 'TITLE' },
  { key: 'company', label: 'COMPANY' },
  { key: 'contact', label: 'REQUESTER' },
  { key: 'status', label: 'STATUS' },
  { key: 'team', label: 'MESA' },
  { key: 'ticket_column', label: 'ESTAGIO' },
  { key: 'assignee', label: 'ASSIGNEE' },
  LAST_COLUMN[props.complexityColumn],
]);

// Pedido: o titulo vem com prefixos tipo "[FORCA E LUZ][DS COMERCIAL]" e some
// truncado antes de dizer o assunto - dar largura maior por padrao, e deixar
// arrastar/ocultar coluna para quem quiser outro equilibrio.
const DEFAULT_COLUMN_WIDTH = {
  display_id: 84,
  created_at: 104,
  title: 320,
  company: 144,
  contact: 144,
  status: 108,
  team: 116,
  ticket_column: 132,
  assignee: 140,
  ticket_complexity: 128,
  ticket_due_date: 116,
};
const MIN_COLUMN_WIDTH = 72;
// Sempre sobra pelo menos uma coluna visivel - ocultar todas deixaria a
// tabela sem nenhuma informacao e sem como religar (o botao de colunas
// tambem estaria escondido atras de uma tabela vazia).
const MIN_VISIBLE_COLUMNS = 1;

// `accountId` chega vazio no modo "Busca detalhada" (nao e passado - ver
// TicketDetailedSearchModal), que ja tem a conta atual pelo store; no modo
// Portal do Cliente ele vem explicito, porque ali nao ha sessao no Vuex.
const scopeAccountId = computed(
  () => props.accountId ?? currentAccountId.value
);

const columnPrefs = ref(
  readColumnPreferences(
    scopeAccountId.value,
    COLUMNS.value.map(column => column.key)
  )
);

watch(scopeAccountId, accountId => {
  columnPrefs.value = readColumnPreferences(
    accountId,
    COLUMNS.value.map(column => column.key)
  );
});

const visibleColumns = computed(() =>
  COLUMNS.value.filter(column => !columnPrefs.value.hidden.includes(column.key))
);

const columnWidth = key =>
  columnPrefs.value.widths[key] || DEFAULT_COLUMN_WIDTH[key] || 140;

const isColumnHideable = key =>
  columnPrefs.value.hidden.includes(key) ||
  visibleColumns.value.length > MIN_VISIBLE_COLUMNS;

const toggleColumn = key => {
  if (!isColumnHideable(key)) return;
  columnPrefs.value = toggleColumnHidden(
    scopeAccountId.value,
    key,
    COLUMNS.value.map(column => column.key)
  );
};

// --- Redimensionar coluna arrastando a borda direita do cabecalho ---
const resizing = ref(null); // { key, startX, startWidth } | null

const onResizeMove = event => {
  if (!resizing.value) return;

  const { key, startX, startWidth } = resizing.value;
  const delta = event.clientX - startX;
  const width = Math.max(MIN_COLUMN_WIDTH, Math.round(startWidth + delta));
  // So em memoria enquanto arrasta - gravar a cada pixel encheria o
  // localStorage de escritas por nada, o valor final e' salvo no mouseup.
  columnPrefs.value = {
    ...columnPrefs.value,
    widths: { ...columnPrefs.value.widths, [key]: width },
  };
};

const onResizeEnd = () => {
  if (resizing.value) {
    setColumnWidth(
      scopeAccountId.value,
      resizing.value.key,
      columnWidth(resizing.value.key),
      COLUMNS.value.map(column => column.key)
    );
  }
  resizing.value = null;
  window.removeEventListener('mousemove', onResizeMove);
  window.removeEventListener('mouseup', onResizeEnd);
};

const onResizeStart = (key, event) => {
  resizing.value = {
    key,
    startX: event.clientX,
    startWidth: columnWidth(key),
  };
  window.addEventListener('mousemove', onResizeMove);
  window.addEventListener('mouseup', onResizeEnd);
};

onBeforeUnmount(() => {
  window.removeEventListener('mousemove', onResizeMove);
  window.removeEventListener('mouseup', onResizeEnd);
});

const showColumnMenu = ref(false);

// Com `groups` a ordenacao acontece aqui, e nao no servidor - entao so valem as
// colunas que `sortTickets` sabe comparar. As demais viram texto simples: um
// cabecalho que parece botao e nao ordena nada e pior que um que nao clica.
const SORT_FIELD_BY_COLUMN = {
  display_id: 'display_id',
  created_at: 'created_at',
  title: 'title',
  company: 'company_name',
  status: 'status',
  assignee: 'assignee_name',
  ticket_complexity: 'ticket_complexity_name',
  ticket_due_date: 'due_date',
};

// Diferente da coluna de abertura (created_at, que vem como epoch unix em
// segundos - por isso o `* 1000` la): `due_date` vem como string ISO 8601
// (`resource.due_date&.iso8601` no jbuilder) - multiplicar por 1000 aqui
// virava NaN -> "Invalid Date". `due_date` e opcional (Estagio pode nao
// exigir prazo), entao fica travessao quando ausente, igual as outras
// colunas sem valor.
const formatDueDate = dueDate =>
  dueDate ? new Date(dueDate).toLocaleDateString() : '—';

const sortBy = ref('');
const sortOrder = ref('asc');

const podeOrdenar = key =>
  !recebeLinhas.value || Boolean(SORT_FIELD_BY_COLUMN[key]);

// Os Estagios recolhidos. Preferencia de quem olha, guardada por (conta, Mesa)
// como a do Kanban - e num `scope` proprio, para uma tela nao mexer na outra.
//
// `validIds` limpa Estagio que nao existe mais: um excluido nao pode ficar
// ressuscitando como recolhido.
const lerRecolhidos = () =>
  recebeLinhas.value
    ? readCollapsedColumnIds(
        props.accountId,
        props.teamId,
        (props.groups || []).map(grupo => Number(grupo.id)),
        COLLAPSE_SCOPE
      )
    : [];

// Lido ja aqui, e nao no `onMounted`: de la a leitura chegaria depois da
// primeira pintura, e os grupos recolhidos piscariam abertos antes de sumir.
const recolhidos = ref(lerRecolhidos());

const estaRecolhido = id => recolhidos.value.includes(Number(id));

const alternarGrupo = id => {
  recolhidos.value = toggleCollapsedColumn(
    props.accountId,
    props.teamId,
    id,
    COLLAPSE_SCOPE
  );
};

// A ordenacao escolhida no cabecalho vale DENTRO de cada Estagio: a separacao
// por Estagio e o que se pediu ver, e ordenar por cima dela desmancharia os
// grupos.
const grupos = computed(() =>
  (props.groups || []).map(grupo => ({
    ...grupo,
    rows: SORT_FIELD_BY_COLUMN[sortBy.value]
      ? sortTickets(grupo.rows, {
          field: SORT_FIELD_BY_COLUMN[sortBy.value],
          direction: sortOrder.value,
        })
      : grupo.rows,
  }))
);

// Sem grupo nenhum com linha, a tela mostra o estado vazio - e nao um
// cabecalho de tabela sozinho.
const temLinhas = computed(() => grupos.value.some(grupo => grupo.rows.length));

const tickets = computed(() =>
  recebeLinhas.value ? [] : store.getters['tickets/getTicketsList']
);

// A tabela desenha UMA sequencia, venha ela de onde vier: no modo `groups` os
// cabecalhos de Estagio entram como linha, e o grupo recolhido simplesmente nao
// contribui com as dele. Manter uma so sequencia evita a marcacao da linha do
// ticket existir duas vezes neste arquivo.
const linhasVisiveis = computed(() => {
  if (!recebeLinhas.value) {
    return tickets.value.map(ticket => ({
      tipo: 'ticket',
      chave: `t-${ticket.id}`,
      ticket,
    }));
  }

  return grupos.value.flatMap(grupo => [
    // Grupo sem nome (lista nao dividida por Estagio, caso da Area do
    // Cliente quando junta todas as Mesas): sem faixa de cabecalho, e por
    // isso nunca recolhido - nao ha botao para recolhe-lo.
    ...(grupo.name ? [{ tipo: 'grupo', chave: `g-${grupo.id}`, grupo }] : []),
    ...(grupo.name && estaRecolhido(grupo.id)
      ? []
      : grupo.rows.map(ticket => ({
          tipo: 'ticket',
          chave: `t-${ticket.id}`,
          ticket,
        }))),
  ]);
});

const vazio = computed(() =>
  recebeLinhas.value ? !temLinhas.value : !tickets.value.length
);

// `count: 0` no modo agrupado esconde a paginacao de proposito: paginar de 25
// em 25 cortaria os grupos ao meio, e e o Estagio recolhido que faz o papel de
// tirar volume da tela.
const listMeta = computed(() =>
  recebeLinhas.value
    ? { currentPage: 1, count: 0 }
    : store.getters['tickets/getListMeta']
);

const isLoading = computed(() =>
  recebeLinhas.value ? props.loading : uiFlags.value.isFetchingList
);

const requestParams = computed(() => ({
  page: listMeta.value.currentPage || 1,
  per_page: PER_PAGE,
  ...toSearchParams(props.filters),
  // Sem coluna escolhida o parametro nao vai, e o servidor mantem a ordem de
  // sempre - mais recentes primeiro.
  sort_by: sortBy.value || undefined,
  sort_order: sortBy.value ? sortOrder.value : undefined,
}));

const loadTickets = (page = 1) => {
  store.dispatch('tickets/fetchTickets', { ...requestParams.value, page });
};

// Primeiro clique ordena crescente; no mesmo cabecalho, inverte. Trocar de
// coluna recomeca crescente e volta para a primeira pagina, porque a ordem
// mudou e a pagina atual deixou de significar o mesmo conjunto.
const sortByColumn = key => {
  if (!podeOrdenar(key)) return;

  if (sortBy.value === key) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortBy.value = key;
    sortOrder.value = 'asc';
  }

  if (recebeLinhas.value) return;
  loadTickets(1);
};

const onPageChange = page => loadTickets(page);

const openTicket = ticket => {
  if (recebeLinhas.value) {
    emit('openTicket', ticket);
    return;
  }
  router.push(
    frontendURL(`accounts/${currentAccountId.value}/tickets/${ticket.id}`)
  );
};

watch(
  () => props.filters,
  () => {
    // Quem entrega os grupos ja os filtrou - nao ha o que recarregar.
    if (recebeLinhas.value) return;
    loadTickets(1);
  },
  { deep: true }
);

// Cada Mesa lembra os proprios Estagios recolhidos, entao trocar de Mesa
// refaz a leitura.
watch(
  () => [props.teamId, props.groups],
  () => {
    recolhidos.value = lerRecolhidos();
  },
  { deep: true }
);

onMounted(() => {
  if (!recebeLinhas.value) loadTickets(1);
});
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-2">
    <div v-if="isLoading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <div v-else-if="vazio" class="flex items-center justify-center flex-1">
      <p class="text-sm text-n-slate-11">{{ t('TICKET.LIST.EMPTY') }}</p>
    </div>

    <template v-else>
      <div class="flex justify-end flex-shrink-0">
        <OnClickOutside @trigger="showColumnMenu = false">
          <div class="relative">
            <button
              type="button"
              class="flex items-center gap-1 px-2 py-1 text-xs rounded-lg text-n-slate-11 hover:bg-n-slate-2 hover:text-n-slate-12"
              @click="showColumnMenu = !showColumnMenu"
            >
              <Icon icon="i-lucide-columns-3" class="size-3.5" />
              {{ t('TICKET.LIST.COLUMNS_BUTTON') }}
            </button>
            <div
              v-if="showColumnMenu"
              class="absolute z-10 py-1 mt-1 border rounded-lg shadow-lg ltr:right-0 rtl:left-0 top-full border-n-weak bg-n-solid-1 min-w-48"
            >
              <label
                v-for="column in COLUMNS"
                :key="column.key"
                class="flex items-center gap-2 px-3 py-1.5 text-sm text-n-slate-12"
                :class="
                  isColumnHideable(column.key)
                    ? 'cursor-pointer hover:bg-n-slate-2'
                    : 'opacity-50 cursor-not-allowed'
                "
              >
                <input
                  type="checkbox"
                  :checked="!columnPrefs.hidden.includes(column.key)"
                  :disabled="!isColumnHideable(column.key)"
                  @change="toggleColumn(column.key)"
                />
                {{ t(`TICKET.LIST.COLUMNS.${column.label}`) }}
              </label>
            </div>
          </div>
        </OnClickOutside>
      </div>

      <div class="flex-1 min-h-0 overflow-auto rounded-xl border border-n-weak">
        <table class="w-full text-sm table-fixed">
          <colgroup>
            <col
              v-for="column in visibleColumns"
              :key="column.key"
              :style="{ width: `${columnWidth(column.key)}px` }"
            />
          </colgroup>
          <thead class="sticky top-0 bg-n-solid-1 border-b border-n-weak">
            <tr class="text-left text-xs text-n-slate-10">
              <th
                v-for="column in visibleColumns"
                :key="column.key"
                class="relative px-3 py-2 font-medium select-none"
                :aria-sort="
                  sortBy === column.key
                    ? sortOrder === 'asc'
                      ? 'ascending'
                      : 'descending'
                    : 'none'
                "
              >
                <component
                  :is="podeOrdenar(column.key) ? 'button' : 'span'"
                  :type="podeOrdenar(column.key) ? 'button' : null"
                  class="flex items-center w-full gap-1 overflow-hidden font-medium transition-colors"
                  :class="[
                    podeOrdenar(column.key)
                      ? 'hover:text-n-slate-12'
                      : 'cursor-default',
                    sortBy === column.key ? 'text-n-slate-12' : '',
                  ]"
                  @click="sortByColumn(column.key)"
                >
                  <span class="truncate">
                    {{ t(`TICKET.LIST.COLUMNS.${column.label}`) }}
                  </span>
                  <!-- A seta so aparece na coluna que esta ordenando, para nao
                       sugerir que todas estao ativas ao mesmo tempo. -->
                  <span
                    v-if="sortBy === column.key"
                    :class="
                      sortOrder === 'asc'
                        ? 'i-lucide-arrow-up'
                        : 'i-lucide-arrow-down'
                    "
                    class="flex-shrink-0 size-3"
                  />
                </component>
                <!-- Alca de redimensionar: arrasta a largura desta coluna.
                     Fora do botao de ordenar, com seu proprio mousedown, para
                     arrastar no canto nao disparar a ordenacao por engano. -->
                <div
                  class="absolute top-0 bottom-0 z-10 w-1.5 -right-0.5 cursor-col-resize hover:bg-n-brand/50"
                  @mousedown.prevent.stop="onResizeStart(column.key, $event)"
                  @click.stop
                />
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="linha in linhasVisiveis" :key="linha.chave">
              <!-- O Estagio. Clicar na faixa inteira recolhe ou abre: e um alvo
                   muito maior que o sinal de mais, e o cliente vai usar isso para
                   esconder o que nao quer acompanhar. -->
              <tr v-if="linha.tipo === 'grupo'" class="bg-n-alpha-black2">
                <td
                  :colspan="visibleColumns.length"
                  class="p-0 border-b border-n-weak"
                >
                  <button
                    type="button"
                    class="flex items-center w-full gap-2 px-3 py-2 text-left transition-colors hover:bg-n-slate-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
                    :aria-expanded="!estaRecolhido(linha.grupo.id)"
                    @click="alternarGrupo(linha.grupo.id)"
                  >
                    <span
                      class="size-3.5 text-n-slate-10"
                      :class="
                        estaRecolhido(linha.grupo.id)
                          ? 'i-lucide-plus'
                          : 'i-lucide-minus'
                      "
                    />
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ linha.grupo.name }}
                    </span>
                    <span class="text-sm text-n-slate-10">
                      ({{ linha.grupo.rows.length }})
                    </span>
                  </button>
                </td>
              </tr>

              <tr
                v-else
                class="border-b border-n-weak last:border-b-0 cursor-pointer hover:bg-n-slate-2"
                @click="openTicket(linha.ticket)"
              >
                <td
                  v-for="column in visibleColumns"
                  :key="column.key"
                  class="px-3 py-2 truncate"
                  :class="
                    column.key === 'title'
                      ? 'text-n-slate-12 font-medium'
                      : 'text-n-slate-11'
                  "
                >
                  <template v-if="column.key === 'display_id'">
                    #{{ linha.ticket.display_id }}
                  </template>
                  <template v-else-if="column.key === 'created_at'">
                    {{
                      new Date(
                        linha.ticket.created_at * 1000
                      ).toLocaleDateString()
                    }}
                  </template>
                  <template v-else-if="column.key === 'title'">
                    {{ linha.ticket.title }}
                  </template>
                  <template v-else-if="column.key === 'company'">
                    {{ linha.ticket.company_name || '—' }}
                  </template>
                  <template v-else-if="column.key === 'contact'">
                    {{ linha.ticket.requester_name || '—' }}
                  </template>
                  <WootLabel
                    v-else-if="column.key === 'status'"
                    :label="
                      t(`TICKET.STATUS.${linha.ticket.status.toUpperCase()}`)
                    "
                    :color="statusColor(linha.ticket.status)"
                    compact
                  />
                  <template v-else-if="column.key === 'team'">
                    {{ linha.ticket.team_name || '—' }}
                  </template>
                  <template v-else-if="column.key === 'ticket_column'">
                    {{ linha.ticket.ticket_column_name || '—' }}
                  </template>
                  <template v-else-if="column.key === 'assignee'">
                    {{ linha.ticket.assignee_name || '—' }}
                  </template>
                  <template v-else>
                    {{
                      props.complexityColumn === 'due_date'
                        ? formatDueDate(linha.ticket.due_date)
                        : linha.ticket.ticket_complexity_name || '—'
                    }}
                  </template>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </template>

    <PaginationFooter
      v-if="listMeta.count > PER_PAGE"
      :current-page="listMeta.currentPage"
      :total-items="listMeta.count"
      :items-per-page="PER_PAGE"
      @update:current-page="onPageChange"
    />
  </div>
</template>
