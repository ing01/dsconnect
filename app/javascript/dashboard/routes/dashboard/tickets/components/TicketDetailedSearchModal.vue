<script setup>
import { computed, reactive, ref, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import CompaniesAPI from 'dashboard/api/companies';
import ContactAPI from 'dashboard/api/contacts';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TicketListView from './TicketListView.vue';
import TicketSelect from './TicketSelect.vue';
import TicketExportButton from './TicketExportButton.vue';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
// Quantos tickets a busca encontrou. Vem do mesmo store que alimenta a lista,
// entao o botao de exportar sabe quando nao ha nada para exportar.
const listMeta = useMapGetter('tickets/getListMeta');
const resultCount = computed(() => listMeta.value?.count || 0);

// Defaults are computed at open time (not hardcoded): first day of the
// current month through today, in the viewer's local timezone.
const toDateInputValue = date => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};
const today = new Date();
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);

// Cada filtro guarda uma lista: escolher duas pessoas procura os tickets de uma
// OU de outra. Entre filtros diferentes continua valendo E.
const emptySelection = () => ({
  status: [],
  companyIds: [],
  contactIds: [],
  assigneeIds: [],
  // Mesa e escolha unica: nenhuma, ou uma so. Os Estagios e as Categorias
  // pertencem a uma Mesa, entao permitir varias deixaria essas duas listas sem
  // dono definido.
  teamId: null,
  ticketColumnIds: [],
  priority: [],
  categoryIds: [],
});

const draft = reactive({
  createdAfter: toDateInputValue(firstDayOfMonth),
  createdBefore: toDateInputValue(today),
  displayId: '',
  title: '',
  ...emptySelection(),
});

// Only applied (and therefore searched) once the agent clicks "Buscar" -
// keeps every keystroke in a text field from firing a request.
const appliedFilters = ref({ ...draft });

// Empresa e Solicitante buscam no servidor, entao a lista muda a cada pesquisa.
// O que ja foi escolhido e guardado a parte, senao o nome sumiria do campo
// assim que a proxima busca trocasse os resultados.
const companyOptions = ref([]);
const contactOptions = ref([]);
const chosenCompanies = ref([]);
const chosenContacts = ref([]);
const isSearchingCompanies = ref(false);
const isSearchingContacts = ref(false);

const mergeChosen = (options, chosen) => {
  const seen = new Set(options.map(option => String(option.value)));
  return [
    ...options,
    ...chosen.filter(option => !seen.has(String(option.value))),
  ];
};

const remember = (store_, values, options) => {
  const known = mergeChosen(options, store_.value);
  store_.value = known.filter(option =>
    values.some(value => String(value) === String(option.value))
  );
};

const searchCompanies = async (query = '') => {
  isSearchingCompanies.value = true;
  try {
    const response = query
      ? await CompaniesAPI.search(query)
      : await CompaniesAPI.get({ page: 1 });
    companyOptions.value = (response.data?.payload ?? []).map(company => ({
      value: company.id,
      label: company.name,
    }));
  } catch (error) {
    companyOptions.value = [];
  } finally {
    isSearchingCompanies.value = false;
  }
};

const searchContacts = async (query = '') => {
  isSearchingContacts.value = true;
  try {
    const response = query
      ? await ContactAPI.search(query)
      : await ContactAPI.get(1);
    contactOptions.value = (response.data?.payload ?? []).map(contact => ({
      value: contact.id,
      label: contact.name,
    }));
  } catch (error) {
    contactOptions.value = [];
  } finally {
    isSearchingContacts.value = false;
  }
};

const statusOptions = computed(() =>
  ['open', 'resolved', 'closed', 'cancelled'].map(status => ({
    value: status,
    label: t(`TICKET.STATUS.${status.toUpperCase()}`),
  }))
);

const priorityOptions = computed(() =>
  ['low', 'medium', 'high', 'urgent'].map(priority => ({
    value: priority,
    label: t(`TICKET.FORM.PRIORITY.${priority.toUpperCase()}`),
  }))
);

const teamOptions = computed(() =>
  props.teams.map(team => ({ value: team.id, label: team.name }))
);

const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);

// Estagios e Categorias so fazem sentido depois que uma Mesa for escolhida, e
// sao sempre os daquela Mesa.
const columnOptions = computed(() => {
  if (!draft.teamId) return [];

  const board = store.getters['ticketColumns/getBoard'](Number(draft.teamId));
  return (board?.ticket_columns || []).map(column => ({
    value: column.id,
    label: column.name,
  }));
});

const categoryOptions = computed(() => {
  if (!draft.teamId) return [];

  return store.getters['ticketColumns/getCategories'](Number(draft.teamId)).map(
    category => ({ value: category.id, label: category.name })
  );
});

const hasTeam = computed(() => !!draft.teamId);

// Trocar a Mesa zera o que pertencia a anterior e carrega as listas da nova.
// Os demais filtros ficam como estao.
watch(
  () => draft.teamId,
  teamId => {
    draft.ticketColumnIds = [];
    draft.categoryIds = [];
    if (!teamId) return;

    store.dispatch('ticketColumns/fetchBoard', Number(teamId));
    store.dispatch('ticketColumns/fetchCategories', Number(teamId));
  }
);

const onCompaniesChange = values =>
  remember(chosenCompanies, values, companyOptions.value);
const onContactsChange = values =>
  remember(chosenContacts, values, contactOptions.value);

const search = () => {
  appliedFilters.value = { ...draft };
};

const clearFilters = () => {
  Object.assign(draft, {
    displayId: '',
    title: '',
    ...emptySelection(),
  });
  chosenCompanies.value = [];
  chosenContacts.value = [];
  search();
};

onMounted(() => {
  store.dispatch('agents/get');
  searchCompanies();
  searchContacts();
  search();
});
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="t('TICKET.SEARCH.TITLE')" />
    <div class="flex flex-col gap-4 px-8 pb-4">
      <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.DATE_FROM') }}
          </span>
          <input
            v-model="draft.createdAfter"
            type="date"
            class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.DATE_TO') }}
          </span>
          <input
            v-model="draft.createdBefore"
            type="date"
            class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.NUMBER') }}
          </span>
          <input
            v-model="draft.displayId"
            type="number"
            class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
          />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.STATUS') }}
          </span>
          <TicketSelect
            v-model="draft.status"
            multiple
            :options="statusOptions"
            :placeholder="t('TICKET.FILTERS.ALL_STATUSES')"
            :aria-label="t('TICKET.SEARCH.STATUS')"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.TITLE_FIELD') }}
          </span>
          <input
            v-model="draft.title"
            type="text"
            class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.COMPANY') }}
          </span>
          <TicketSelect
            v-model="draft.companyIds"
            multiple
            show-search
            disable-local-filtering
            :options="mergeChosen(companyOptions, chosenCompanies)"
            :is-searching="isSearchingCompanies"
            :placeholder="t('TICKET.COMPANY.PLACEHOLDER')"
            :search-placeholder="t('TICKET.COMPANY.SEARCH')"
            :aria-label="t('TICKET.SEARCH.COMPANY')"
            empty-state-message="TICKET.COMPANY.EMPTY"
            @search="searchCompanies"
            @select="onCompaniesChange"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.CONTACT') }}
          </span>
          <TicketSelect
            v-model="draft.contactIds"
            multiple
            show-search
            disable-local-filtering
            :options="mergeChosen(contactOptions, chosenContacts)"
            :is-searching="isSearchingContacts"
            :placeholder="t('TICKET.SEARCH.CONTACT')"
            :aria-label="t('TICKET.SEARCH.CONTACT')"
            @search="searchContacts"
            @select="onContactsChange"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.ASSIGNEE') }}
          </span>
          <TicketSelect
            v-model="draft.assigneeIds"
            multiple
            show-search
            :options="agentOptions"
            :placeholder="t('TICKET.FORM.ASSIGNEE.NONE')"
            :aria-label="t('TICKET.SEARCH.ASSIGNEE')"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.MESA') }}
          </span>
          <TicketSelect
            v-model="draft.teamId"
            :options="teamOptions"
            clearable
            :clear-label="t('TICKET.SEARCH.ALL_MESAS')"
            :placeholder="t('TICKET.SEARCH.ALL_MESAS')"
            :aria-label="t('TICKET.SEARCH.MESA')"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.ESTAGIO') }}
          </span>
          <TicketSelect
            v-model="draft.ticketColumnIds"
            multiple
            :disabled="!hasTeam"
            :options="columnOptions"
            :placeholder="t('TICKET.SEARCH.ALL_ESTAGIOS')"
            :aria-label="t('TICKET.SEARCH.ESTAGIO')"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.FORM.PRIORITY.LABEL') }}
          </span>
          <TicketSelect
            v-model="draft.priority"
            multiple
            :options="priorityOptions"
            :placeholder="t('TICKET.FILTERS.ALL_PRIORITIES')"
            :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
          />
        </label>

        <label class="flex flex-col gap-1 col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.CREATE.CATEGORY') }}
          </span>
          <TicketSelect
            v-model="draft.categoryIds"
            multiple
            :disabled="!hasTeam"
            :options="categoryOptions"
            :placeholder="t('TICKET.SEARCH.ALL_CATEGORIES')"
            :aria-label="t('TICKET.CREATE.CATEGORY')"
          />
        </label>
      </div>

      <div class="flex items-center justify-end gap-2">
        <NextButton
          ghost
          slate
          size="sm"
          :label="t('TICKET.FILTERS.CLEAR')"
          @click="clearFilters"
        />
        <NextButton
          size="sm"
          icon="i-lucide-search"
          :label="t('TICKET.SEARCH.SUBMIT')"
          @click="search"
        />

        <!-- Exporta o resultado da busca aplicada, nao a pagina aberta. -->
        <TicketExportButton :filters="appliedFilters" :count="resultCount" />
      </div>

      <TicketListView :filters="appliedFilters" class="h-96" />
    </div>
  </div>
</template>
