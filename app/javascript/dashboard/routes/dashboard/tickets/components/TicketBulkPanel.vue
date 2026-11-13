<script setup>
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BulkAPI from 'dashboard/api/ticketBulkOperations';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TicketSelect from './TicketSelect.vue';
import TicketCompanySelect from './TicketCompanySelect.vue';
import TicketContactSelect from './TicketContactSelect.vue';
import TicketCatalogSelect from './detail/actions/TicketCatalogSelect.vue';
import { toSearchParams } from '../helpers/ticketSearchParams';

/**
 * Painel de ações em lote da Busca detalhada.
 *
 * Fluxo: escolher o alcance (marcados ou todos do filtro) e a ação, revisar o
 * ensaio ("N tickets, X sem permissão"), confirmar, acompanhar o andamento e
 * ler o relatório. Operações de campo podem ser desfeitas por 24h.
 */
const props = defineProps({
  selectedIds: { type: Array, default: () => [] },
  filters: { type: Object, required: true },
  resultCount: { type: Number, default: 0 },
  teams: { type: Array, default: () => [] },
});

const emit = defineEmits(['done', 'clearSelection']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');

const SELECTION_LIMIT = 200;
const FILTER_LIMIT = 500;

const GROUPS = [
  {
    key: 'FIELDS',
    actions: [
      'priority',
      'due_date',
      'scheduled_at',
      'category',
      'complexity',
      'assignee',
      'contact_company',
      'followers',
    ],
  },
  { key: 'MOVE', actions: ['stage', 'team'] },
  { key: 'COMMUNICATE', actions: ['comment', 'customer_message'] },
  { key: 'FINISH', actions: ['resolve', 'close', 'cancel', 'reopen'] },
];
// Ações que a API desfaz (espelha Handlers::REVERSIBLE).
const NEEDS_TEAM = ['category', 'stage', 'close'];

const scope = ref('selected');
const action = ref(null);
const form = reactive({
  priority: null,
  dueDate: '',
  clearDate: false,
  scheduledAt: '',
  teamId: null,
  ticketColumnId: null,
  categoryId: null,
  complexityId: null,
  userId: null,
  level: 1,
  companyId: null,
  contactId: null,
  userIds: [],
  body: '',
  notifyCustomer: true,
  resolution: '',
  reason: '',
  catalogId: null,
  areaId: null,
  itemId: null,
});

// 'form' -> 'review' (ensaio) -> 'running' -> 'report'
const step = ref('form');
const preview = ref(null);
const operation = ref(null);
const report = ref(null);
const history = ref([]);
const isBusy = ref(false);
let pollTimer = null;

const targetCount = computed(() =>
  scope.value === 'selected' ? props.selectedIds.length : props.resultCount
);
const limit = computed(() =>
  scope.value === 'selected' ? SELECTION_LIMIT : FILTER_LIMIT
);
const overLimit = computed(() => targetCount.value > limit.value);

const actionOptions = computed(() =>
  GROUPS.flatMap(group =>
    group.actions.map(key => ({
      value: key,
      label: `${t(`TICKET.BULK.GROUPS.${group.key}`)} · ${t(`TICKET.BULK.ACTIONS.${key}`)}`,
    }))
  )
);

const teamOptions = computed(() =>
  props.teams.map(team => ({ value: team.id, label: team.name }))
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const priorityOptions = computed(() =>
  ['low', 'medium', 'high', 'urgent'].map(priority => ({
    value: priority,
    label: t(`TICKET.FORM.PRIORITY.${priority.toUpperCase()}`),
  }))
);
const levelOptions = [1, 2, 3, 4, 5].map(level => ({
  value: level,
  label: t('TICKET.BULK.FIELDS.LEVEL', { level }),
}));
const complexityOptions = computed(() =>
  (store.getters['ticketComplexities/getComplexities'] || []).map(item => ({
    value: item.id,
    label: item.name,
  }))
);
const columnOptions = computed(() => {
  if (!form.teamId) return [];
  const board = store.getters['ticketColumns/getBoard'](Number(form.teamId));
  return (board?.ticket_columns || []).map(column => ({
    value: column.id,
    label: column.name,
  }));
});
const categoryOptions = computed(() => {
  if (!form.teamId) return [];
  return store.getters['ticketColumns/getCategories'](Number(form.teamId)).map(
    category => ({ value: category.id, label: category.name })
  );
});

watch(
  () => form.teamId,
  teamId => {
    form.ticketColumnId = null;
    form.categoryId = null;
    if (!teamId) return;
    store.dispatch('ticketColumns/fetchBoard', Number(teamId));
    store.dispatch('ticketColumns/fetchCategories', Number(teamId));
  }
);

watch(action, key => {
  step.value = 'form';
  preview.value = null;
  if (['complexity', 'close'].includes(key)) {
    store.dispatch('ticketComplexities/fetch');
  }
  if (key === 'close') store.dispatch('serviceCatalogs/fetch');
});

const needsTeam = computed(() => NEEDS_TEAM.includes(action.value));

// O que a ação manda ao servidor.
const operationPayload = computed(() => {
  switch (action.value) {
    case 'priority':
      return { priority: form.priority };
    case 'due_date':
      return { due_date: form.clearDate ? null : form.dueDate };
    case 'scheduled_at':
      return { scheduled_at: form.clearDate ? null : form.scheduledAt };
    case 'category':
      return { ticket_category_id: form.categoryId };
    case 'complexity':
      return { ticket_complexity_id: form.complexityId };
    case 'assignee':
      return { user_id: form.userId, level: form.level };
    case 'contact_company':
      return {
        ...(form.companyId ? { company_id: form.companyId } : {}),
        ...(form.contactId ? { contact_id: form.contactId } : {}),
      };
    case 'followers':
      return { user_ids: form.userIds };
    case 'stage':
      return { ticket_column_id: form.ticketColumnId };
    case 'team':
      return { team_id: form.teamId, ticket_column_id: form.ticketColumnId };
    case 'comment':
      return { body: form.body };
    case 'customer_message':
      return { body: form.body, notify_customer: form.notifyCustomer };
    case 'close':
      return {
        resolution: form.resolution,
        ticket_category_id: form.categoryId,
        service_catalog_item_id: form.itemId,
      };
    case 'cancel':
      return { reason: form.reason };
    default:
      return {};
  }
});

const isFormValid = computed(() => {
  const value = operationPayload.value;
  switch (action.value) {
    case 'priority':
      return !!value.priority;
    case 'due_date':
      return form.clearDate || !!form.dueDate;
    case 'scheduled_at':
      return form.clearDate || !!form.scheduledAt;
    case 'category':
      return !!form.teamId;
    case 'complexity':
    case 'assignee':
      return true;
    case 'contact_company':
      return !!(form.companyId || form.contactId);
    case 'followers':
      return form.userIds.length > 0;
    case 'stage':
      return !!form.ticketColumnId;
    case 'team':
      return !!form.teamId;
    case 'comment':
    case 'customer_message':
      return !!form.body.trim();
    case 'cancel':
      return !!form.reason.trim();
    case 'close':
      return true;
    default:
      return !!action.value;
  }
});

const canReview = computed(
  () =>
    !!action.value &&
    isFormValid.value &&
    targetCount.value > 0 &&
    !overLimit.value &&
    !isBusy.value
);

const target = () =>
  scope.value === 'selected'
    ? { ticketIds: props.selectedIds }
    : { filters: toSearchParams(props.filters) };

// Trocar categoria em lote agora tambem alcanca ticket fechado/cancelado
// (pedido da Ingrid, 2026-11-14) - mas precisa ser uma escolha explicita, nao
// um efeito colateral silencioso. `excludeFinalized` manda o backend pular os
// ja finalizados mesmo que estejam no escopo (selecionados ou filtro).
const request = (excludeFinalized = false) => ({
  action: action.value,
  operation: operationPayload.value,
  excludeFinalized,
  ...target(),
});

const apiError = error =>
  error?.response?.data?.error || t('TICKET.BULK.ERROR');

const review = async () => {
  isBusy.value = true;
  try {
    const { data } = await BulkAPI.preview(request());
    preview.value = data;
    step.value = 'review';
  } catch (error) {
    useAlert(apiError(error));
  } finally {
    isBusy.value = false;
  }
};

const stopPolling = () => {
  if (pollTimer) clearTimeout(pollTimer);
  pollTimer = null;
};

const loadHistory = async () => {
  try {
    const { data } = await BulkAPI.get();
    history.value = data.payload || [];
  } catch (error) {
    history.value = [];
  }
};

const poll = async id => {
  try {
    const { data } = await BulkAPI.show(id);
    operation.value = data;
    if (['pending', 'running'].includes(data.status)) {
      pollTimer = setTimeout(() => poll(id), 1500);
      return;
    }
    report.value = data;
    step.value = 'report';
    loadHistory();
    emit('done');
  } catch (error) {
    useAlert(apiError(error));
    step.value = 'form';
  }
};

const track = created => {
  operation.value = created;
  report.value = null;
  step.value = 'running';
  stopPolling();
  poll(created.id);
};

const confirm = async (excludeFinalized = false) => {
  isBusy.value = true;
  try {
    const { data } = await BulkAPI.run(request(excludeFinalized));
    track(data);
  } catch (error) {
    useAlert(apiError(error));
  } finally {
    isBusy.value = false;
  }
};

const undo = async id => {
  try {
    const { data } = await BulkAPI.undo(id);
    track(data);
  } catch (error) {
    useAlert(apiError(error));
  }
};

const retryFailed = async id => {
  try {
    const { data } = await BulkAPI.retryFailed(id);
    track(data);
  } catch (error) {
    useAlert(apiError(error));
  }
};

const reset = () => {
  stopPolling();
  step.value = 'form';
  preview.value = null;
  operation.value = null;
  report.value = null;
};

const progress = computed(() => {
  const op = operation.value;
  if (!op?.total) return 0;
  return Math.round(((op.succeeded + op.skipped + op.failed) / op.total) * 100);
});

const problemItems = computed(() =>
  (report.value?.items || []).filter(item => item.outcome !== 'succeeded')
);

const downloadCsv = () => {
  const rows = [['ticket', 'resultado', 'motivo']].concat(
    (report.value?.items || []).map(item => [
      item.display_id,
      item.outcome,
      item.reason || '',
    ])
  );
  const csv = rows
    .map(row =>
      row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(';')
    )
    .join('\n');
  const link = document.createElement('a');
  const bom = String.fromCharCode(0xfeff);
  const blob = new Blob([`${bom}${csv}`], { type: 'text/csv' });
  link.href = URL.createObjectURL(blob);
  link.download = `lote-${report.value.id}.csv`;
  link.click();
  URL.revokeObjectURL(link.href);
};

const actionLabel = key => t(`TICKET.BULK.ACTIONS.${key}`);

loadHistory();
onBeforeUnmount(stopPolling);
</script>

<template>
  <section
    class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
  >
    <header class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ t('TICKET.BULK.TITLE') }}
      </h3>
      <div class="flex items-center gap-3 text-sm text-n-slate-11">
        <label class="flex items-center gap-1">
          <input v-model="scope" type="radio" value="selected" />
          {{ t('TICKET.BULK.SCOPE.SELECTED', { count: selectedIds.length }) }}
        </label>
        <label class="flex items-center gap-1">
          <input v-model="scope" type="radio" value="filter" />
          {{ t('TICKET.BULK.SCOPE.FILTER', { count: resultCount }) }}
        </label>
        <NextButton
          v-if="selectedIds.length"
          ghost
          slate
          xs
          :label="t('TICKET.BULK.CLEAR_SELECTION')"
          @click="emit('clearSelection')"
        />
      </div>
    </header>

    <p v-if="overLimit" class="m-0 text-sm text-n-ruby-11">
      {{ t('TICKET.BULK.OVER_LIMIT', { limit }) }}
    </p>

    <!-- 1. Escolher e preencher -->
    <template v-if="step === 'form'">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
        <label class="flex flex-col gap-1 md:col-span-2">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.BULK.ACTION') }}
          </span>
          <TicketSelect
            v-model="action"
            :options="actionOptions"
            :placeholder="t('TICKET.BULK.ACTION_PLACEHOLDER')"
            :aria-label="t('TICKET.BULK.ACTION')"
          />
        </label>

        <label
          v-if="needsTeam || action === 'team'"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.MESA') }}
          </span>
          <TicketSelect
            v-model="form.teamId"
            :options="teamOptions"
            :placeholder="t('TICKET.SEARCH.MESA')"
            :aria-label="t('TICKET.SEARCH.MESA')"
          />
        </label>

        <label v-if="action === 'priority'" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.FORM.PRIORITY.LABEL') }}
          </span>
          <TicketSelect
            v-model="form.priority"
            :options="priorityOptions"
            :aria-label="t('TICKET.FORM.PRIORITY.LABEL')"
          />
        </label>

        <template v-if="action === 'due_date' || action === 'scheduled_at'">
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t(`TICKET.BULK.ACTIONS.${action}`) }}
            </span>
            <input
              v-if="action === 'due_date'"
              v-model="form.dueDate"
              type="datetime-local"
              :disabled="form.clearDate"
              class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
            />
            <input
              v-else
              v-model="form.scheduledAt"
              type="datetime-local"
              :disabled="form.clearDate"
              class="px-2 text-sm bg-transparent border rounded-lg h-10 border-n-strong"
            />
          </label>
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <input v-model="form.clearDate" type="checkbox" />
            {{ t('TICKET.BULK.FIELDS.CLEAR_DATE') }}
          </label>
        </template>

        <label v-if="action === 'category'" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.CREATE.CATEGORY') }}
          </span>
          <TicketSelect
            v-model="form.categoryId"
            clearable
            :clear-label="t('TICKET.BULK.FIELDS.NO_CATEGORY')"
            :disabled="!form.teamId"
            :options="categoryOptions"
            :aria-label="t('TICKET.CREATE.CATEGORY')"
          />
        </label>

        <label v-if="action === 'complexity'" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.COMPLEXITY.LABEL') }}
          </span>
          <TicketSelect
            v-model="form.complexityId"
            clearable
            :clear-label="t('TICKET.BULK.FIELDS.NO_COMPLEXITY')"
            :options="complexityOptions"
            :aria-label="t('TICKET.COMPLEXITY.LABEL')"
          />
        </label>

        <template v-if="action === 'assignee'">
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.SEARCH.ASSIGNEE') }}
            </span>
            <TicketSelect
              v-model="form.userId"
              show-search
              clearable
              :clear-label="t('TICKET.BULK.FIELDS.NO_ASSIGNEE')"
              :options="agentOptions"
              :aria-label="t('TICKET.SEARCH.ASSIGNEE')"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.BULK.FIELDS.LEVEL_LABEL') }}
            </span>
            <TicketSelect
              v-model="form.level"
              :options="levelOptions"
              :aria-label="t('TICKET.BULK.FIELDS.LEVEL_LABEL')"
            />
          </label>
        </template>

        <template v-if="action === 'contact_company'">
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.SEARCH.COMPANY') }}
            </span>
            <TicketCompanySelect v-model="form.companyId" />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.SEARCH.CONTACT') }}
            </span>
            <TicketContactSelect
              v-model="form.contactId"
              :company-id="form.companyId"
            />
          </label>
        </template>

        <label v-if="action === 'followers'" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.BULK.ACTIONS.followers') }}
          </span>
          <TicketSelect
            v-model="form.userIds"
            multiple
            show-search
            :options="agentOptions"
            :aria-label="t('TICKET.BULK.ACTIONS.followers')"
          />
        </label>

        <label
          v-if="action === 'stage' || action === 'team'"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.SEARCH.ESTAGIO') }}
          </span>
          <TicketSelect
            v-model="form.ticketColumnId"
            :disabled="!form.teamId"
            clearable
            :options="columnOptions"
            :placeholder="
              action === 'team' ? t('TICKET.BULK.FIELDS.FIRST_STAGE') : ''
            "
            :aria-label="t('TICKET.SEARCH.ESTAGIO')"
          />
        </label>

        <p
          v-if="action === 'team'"
          class="m-0 text-xs md:col-span-2 text-n-slate-11"
        >
          {{ t('TICKET.BULK.FIELDS.TEAM_CLEARS_ASSIGNEE') }}
        </p>

        <label
          v-if="action === 'comment' || action === 'customer_message'"
          class="flex flex-col gap-1 md:col-span-2"
        >
          <span class="text-xs text-n-slate-11">
            {{ t(`TICKET.BULK.ACTIONS.${action}`) }}
          </span>
          <textarea
            v-model="form.body"
            rows="4"
            class="px-2 py-1 text-sm bg-transparent border rounded-lg border-n-strong"
          />
        </label>
        <template v-if="action === 'customer_message'">
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <input v-model="form.notifyCustomer" type="checkbox" />
            {{ t('TICKET.BULK.FIELDS.NOTIFY_CUSTOMER') }}
          </label>
          <p class="m-0 text-xs md:col-span-2 text-n-slate-11">
            {{ t('TICKET.BULK.FIELDS.CONSOLIDATED') }}
          </p>
        </template>

        <label
          v-if="action === 'cancel'"
          class="flex flex-col gap-1 md:col-span-2"
        >
          <span class="text-xs text-n-slate-11">
            {{ t('TICKET.BULK.FIELDS.CANCEL_REASON') }}
          </span>
          <textarea
            v-model="form.reason"
            rows="2"
            class="px-2 py-1 text-sm bg-transparent border rounded-lg border-n-strong"
          />
        </label>

        <!-- Fechar: o que for preenchido vale para TODOS os tickets. -->
        <div
          v-if="action === 'close'"
          class="flex flex-col gap-3 p-3 border rounded-lg md:col-span-2 border-n-ruby-6 bg-n-ruby-2"
        >
          <p class="m-0 text-sm font-medium text-n-ruby-11">
            {{ t('TICKET.BULK.CLOSE.WARNING', { count: targetCount }) }}
          </p>
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.BULK.CLOSE.RESOLUTION') }}
            </span>
            <textarea
              v-model="form.resolution"
              rows="3"
              class="px-2 py-1 text-sm bg-transparent border rounded-lg border-n-strong"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ t('TICKET.BULK.CLOSE.CATEGORY') }}
            </span>
            <TicketSelect
              v-model="form.categoryId"
              clearable
              :clear-label="t('TICKET.BULK.CLOSE.KEEP')"
              :disabled="!form.teamId"
              :options="categoryOptions"
              :placeholder="t('TICKET.BULK.CLOSE.KEEP')"
              :aria-label="t('TICKET.BULK.CLOSE.CATEGORY')"
            />
          </label>
          <TicketCatalogSelect
            v-model:catalog-id="form.catalogId"
            v-model:area-id="form.areaId"
            v-model:item-id="form.itemId"
            :catalogs="catalogs"
          />
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('TICKET.BULK.CLOSE.HINT') }}
          </p>
        </div>
      </div>

      <div class="flex justify-end">
        <NextButton
          size="sm"
          :disabled="!canReview"
          :is-loading="isBusy"
          :label="t('TICKET.BULK.REVIEW')"
          @click="review"
        />
      </div>
    </template>

    <!-- 2. Ensaio e confirmação -->
    <template v-else-if="step === 'review' && preview">
      <div class="flex flex-col gap-1 p-3 text-sm rounded-lg bg-n-alpha-black2">
        <strong class="text-n-slate-12">
          {{
            t('TICKET.BULK.REVIEW_SUMMARY', {
              action: actionLabel(action),
              count: preview.total,
            })
          }}
        </strong>
        <span v-if="preview.forbidden" class="text-n-ruby-11">
          {{ t('TICKET.BULK.REVIEW_FORBIDDEN', { count: preview.forbidden }) }}
        </span>
        <span v-if="preview.finalized" class="text-n-slate-11">
          {{ t('TICKET.BULK.REVIEW_FINALIZED', { count: preview.finalized }) }}
        </span>
        <strong v-if="action === 'close'" class="text-n-ruby-11">
          {{ t('TICKET.BULK.CLOSE.WARNING', { count: preview.total }) }}
        </strong>
        <!-- Troca de categoria agora alcanca ticket fechado/cancelado, mas
             isso precisa ser uma escolha explicita de quem pediu a acao, nao
             um efeito colateral silencioso - pedido da Ingrid, 2026-11-14. -->
        <strong
          v-if="action === 'category' && preview.finalized"
          class="text-n-amber-11"
        >
          {{ t('TICKET.BULK.CATEGORY_FINALIZED_QUESTION', { count: preview.finalized }) }}
        </strong>
      </div>
      <div
        v-if="action === 'category' && preview.finalized"
        class="flex justify-end gap-2"
      >
        <NextButton
          ghost
          slate
          size="sm"
          :label="t('TICKET.BULK.BACK')"
          @click="reset"
        />
        <NextButton
          ghost
          slate
          size="sm"
          :is-loading="isBusy"
          :label="t('TICKET.BULK.CATEGORY_FINALIZED_EXCLUDE')"
          @click="confirm(true)"
        />
        <NextButton
          size="sm"
          :is-loading="isBusy"
          :label="t('TICKET.BULK.CATEGORY_FINALIZED_INCLUDE')"
          @click="confirm(false)"
        />
      </div>
      <div v-else class="flex justify-end gap-2">
        <NextButton
          ghost
          slate
          size="sm"
          :label="t('TICKET.BULK.BACK')"
          @click="reset"
        />
        <NextButton
          size="sm"
          :is-loading="isBusy"
          :label="t('TICKET.BULK.CONFIRM', { count: preview.total })"
          @click="confirm()"
        />
      </div>
    </template>

    <!-- 3. Andamento -->
    <template v-else-if="step === 'running' && operation">
      <p class="m-0 text-sm text-n-slate-12">
        {{ t('TICKET.BULK.RUNNING', { progress }) }}
      </p>
      <div class="h-2 overflow-hidden rounded-full bg-n-alpha-black2">
        <div
          class="h-full transition-all bg-n-brand"
          :style="{ width: `${progress}%` }"
        />
      </div>
    </template>

    <!-- 4. Relatório -->
    <template v-else-if="step === 'report' && report">
      <div class="flex flex-col gap-2 text-sm">
        <strong class="text-n-slate-12">
          {{
            t('TICKET.BULK.REPORT.SUMMARY', {
              succeeded: report.succeeded,
              skipped: report.skipped,
              failed: report.failed,
            })
          }}
        </strong>
        <ul
          v-if="problemItems.length"
          class="m-0 overflow-auto list-none max-h-40 text-n-slate-11"
        >
          <li v-for="item in problemItems" :key="item.ticket_id">
            #{{ item.display_id }} — {{ item.reason }}
          </li>
        </ul>
      </div>
      <div class="flex flex-wrap justify-end gap-2">
        <NextButton
          ghost
          slate
          size="sm"
          :label="t('TICKET.BULK.REPORT.DOWNLOAD')"
          @click="downloadCsv"
        />
        <NextButton
          v-if="report.failed"
          ghost
          slate
          size="sm"
          :label="t('TICKET.BULK.REPORT.RETRY')"
          @click="retryFailed(report.id)"
        />
        <NextButton
          v-if="report.undoable"
          faded
          ruby
          size="sm"
          :label="t('TICKET.BULK.REPORT.UNDO')"
          @click="undo(report.id)"
        />
        <NextButton
          size="sm"
          :label="t('TICKET.BULK.REPORT.NEW')"
          @click="reset"
        />
      </div>
    </template>

    <!-- Histórico recente -->
    <details v-if="history.length" class="text-sm">
      <summary class="cursor-pointer text-n-slate-11">
        {{ t('TICKET.BULK.HISTORY') }}
      </summary>
      <ul class="mt-2 mb-0 list-none">
        <li
          v-for="op in history"
          :key="op.id"
          class="flex items-center justify-between gap-2 py-1 border-b border-n-weak text-n-slate-11"
        >
          <span>
            {{ actionLabel(op.action) }} · {{ op.succeeded }}/{{ op.total }} ·
            {{ op.user?.name }}
          </span>
          <NextButton
            v-if="op.undoable"
            ghost
            ruby
            xs
            :label="t('TICKET.BULK.REPORT.UNDO')"
            @click="undo(op.id)"
          />
        </li>
      </ul>
    </details>
  </section>
</template>
