<script setup>
/**
 * "SAC e Sugestões" do lado da equipe: a listagem com filtros.
 *
 * Os filtros vão para o SERVIDOR (`ManifestationFinder`) e não recortam o que
 * já foi baixado: o acervo cresce com o tempo, e filtrar no navegador obrigaria
 * a baixar tudo para mostrar pouco.
 *
 * Os contadores do topo também vêm do servidor, e contam a CONTA inteira - não
 * o resultado do filtro atual. "Pendentes: 3" precisa significar que há três
 * esperando resposta, e não três dentro do recorte que está na tela.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import {
  statusColor,
  kindColor,
  kindOptions,
  subjectAreaOptions,
  statusOptions,
} from '../helpers/manifestationLabels';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const router = useRouter();

const items = computed(() => getters['manifestations/getManifestations'].value);
const counts = computed(() => getters['manifestations/getCounts'].value);
const uiFlags = computed(() => getters['manifestations/getUIFlags'].value);
const agents = computed(() => getters['agents/getVerifiedAgents'].value || []);

// O estado dos filtros. Vazio = sem recorte, e é esse o estado inicial: a
// equipe abre a tela para ver o que chegou, não para montar uma consulta.
const filtros = ref({
  query: '',
  kind: '',
  subject_area: '',
  status: '',
  assignee_id: '',
  created_after: '',
  created_before: '',
  pending_only: false,
});

const tipos = computed(() => kindOptions(t));
const assuntos = computed(() => subjectAreaOptions(t));
const statuses = computed(() => statusOptions(t));

const temFiltro = computed(() =>
  Object.entries(filtros.value).some(([, valor]) =>
    typeof valor === 'boolean' ? valor : String(valor || '').length > 0
  )
);

const tableHeaders = computed(() => [
  t('MANIFESTATION.LIST.COLUMNS.REFERENCE'),
  t('MANIFESTATION.LIST.COLUMNS.TITLE'),
  t('MANIFESTATION.LIST.COLUMNS.KIND'),
  t('MANIFESTATION.LIST.COLUMNS.SUBJECT_AREA'),
  t('MANIFESTATION.LIST.COLUMNS.COMPANY'),
  t('MANIFESTATION.LIST.COLUMNS.STATUS'),
  t('MANIFESTATION.LIST.COLUMNS.ASSIGNEE'),
  t('MANIFESTATION.LIST.COLUMNS.CREATED_AT'),
]);

const dataHora = segundos =>
  segundos ? new Date(segundos * 1000).toLocaleString() : '';

// Só manda o que foi preenchido: parâmetro vazio no servidor é filtro ignorado,
// mas enviar uma dúzia deles em branco deixa a URL ilegível no log.
const parametros = () =>
  Object.fromEntries(
    Object.entries(filtros.value).filter(([, valor]) =>
      typeof valor === 'boolean' ? valor : String(valor || '').length > 0
    )
  );

const buscar = async () => {
  try {
    await store.dispatch('manifestations/fetch', parametros());
  } catch {
    useAlert(t('MANIFESTATION.API.ERROR'));
  }
};

const limpar = async () => {
  filtros.value = {
    query: '',
    kind: '',
    subject_area: '',
    status: '',
    assignee_id: '',
    created_after: '',
    created_before: '',
    pending_only: false,
  };
  await buscar();
};

const abrir = item =>
  router.push({
    name: 'manifestation_detail',
    params: { manifestationId: item.id },
  });

onMounted(async () => {
  await store.dispatch('agents/get');
  await buscar();
});
</script>

<template>
  <div class="flex flex-col h-full gap-4 p-4 overflow-hidden min-w-0 sm:p-6">
    <div class="flex flex-wrap items-start justify-between flex-shrink-0 gap-3">
      <div class="min-w-0">
        <h1 class="m-0 text-xl font-medium text-n-slate-12">
          {{ t('MANIFESTATION.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-n-slate-11">
          {{ t('MANIFESTATION.DESCRIPTION') }}
        </p>
      </div>

      <!-- Os contadores: o que precisa de atenção, visível sem abrir nada. -->
      <div class="flex flex-wrap items-center flex-shrink-0 gap-2">
        <span
          class="px-3 py-1.5 text-xs rounded-lg bg-n-slate-3 text-n-slate-12"
        >
          {{ t('MANIFESTATION.LIST.COUNT_TOTAL') }}: {{ counts.total }}
        </span>
        <span
          class="px-3 py-1.5 text-xs rounded-lg bg-n-amber-3 text-n-amber-11"
        >
          {{ t('MANIFESTATION.LIST.COUNT_PENDING') }}: {{ counts.pending }}
        </span>
        <span class="px-3 py-1.5 text-xs rounded-lg bg-n-blue-3 text-n-blue-11">
          {{ t('MANIFESTATION.LIST.COUNT_UNTOUCHED') }}: {{ counts.untouched }}
        </span>
      </div>
    </div>

    <div
      class="flex flex-wrap items-end flex-shrink-0 gap-3 p-4 border rounded-xl border-n-weak min-w-0"
    >
      <label class="flex flex-col gap-1 grow min-w-48">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FILTERS.SEARCH') }}
        </span>
        <input
          v-model="filtros.query"
          type="text"
          class="w-full mb-0"
          @keyup.enter="buscar"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-36">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FIELDS.KIND') }}
        </span>
        <select v-model="filtros.kind" class="w-full mb-0" @change="buscar">
          <option value="">{{ t('MANIFESTATION.FILTERS.ALL_KINDS') }}</option>
          <option v-for="o in tipos" :key="o.value" :value="o.value">
            {{ o.label }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-36">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FIELDS.SUBJECT_AREA') }}
        </span>
        <select
          v-model="filtros.subject_area"
          class="w-full mb-0"
          @change="buscar"
        >
          <option value="">
            {{ t('MANIFESTATION.FILTERS.ALL_SUBJECTS') }}
          </option>
          <option v-for="o in assuntos" :key="o.value" :value="o.value">
            {{ o.label }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-36">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FIELDS.STATUS') }}
        </span>
        <select v-model="filtros.status" class="w-full mb-0" @change="buscar">
          <option value="">
            {{ t('MANIFESTATION.FILTERS.ALL_STATUSES') }}
          </option>
          <option v-for="o in statuses" :key="o.value" :value="o.value">
            {{ o.label }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-36">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FIELDS.ASSIGNEE') }}
        </span>
        <select
          v-model="filtros.assignee_id"
          class="w-full mb-0"
          @change="buscar"
        >
          <option value="">
            {{ t('MANIFESTATION.FILTERS.ALL_ASSIGNEES') }}
          </option>
          <option v-for="agente in agents" :key="agente.id" :value="agente.id">
            {{ agente.name }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 min-w-32">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FILTERS.FROM') }}
        </span>
        <input
          v-model="filtros.created_after"
          type="date"
          class="w-full mb-0"
          @change="buscar"
        />
      </label>

      <label class="flex flex-col gap-1 min-w-32">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MANIFESTATION.FILTERS.TO') }}
        </span>
        <input
          v-model="filtros.created_before"
          type="date"
          class="w-full mb-0"
          @change="buscar"
        />
      </label>

      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input
          v-model="filtros.pending_only"
          type="checkbox"
          class="mb-0"
          @change="buscar"
        />
        {{ t('MANIFESTATION.FILTERS.PENDING_ONLY') }}
      </label>

      <Button
        v-if="temFiltro"
        variant="faded"
        color="slate"
        size="sm"
        :label="t('MANIFESTATION.FILTERS.CLEAR')"
        @click="limpar"
      />
    </div>

    <div
      v-if="uiFlags.isFetching"
      class="flex justify-center py-16 text-n-slate-10"
    >
      <Spinner />
    </div>

    <div v-else class="overflow-auto grow min-h-0 min-w-0">
      <BaseTable
        :headers="tableHeaders"
        :items="items"
        :no-data-message="
          temFiltro
            ? t('MANIFESTATION.LIST.EMPTY_FILTERED')
            : t('MANIFESTATION.LIST.EMPTY')
        "
      >
        <template #row="{ items: linhas }">
          <BaseTableRow
            v-for="item in linhas"
            :key="item.id"
            class="cursor-pointer"
            @click="abrir(item)"
          >
            <BaseTableCell>
              <span class="flex items-center gap-2 min-w-0">
                <span class="text-sm text-n-slate-12">
                  {{ item.reference }}
                </span>
                <!-- "Nova" = ninguém mexeu ainda. É o que a equipe procura ao
                     abrir a tela. -->
                <span
                  v-if="item.status === 'received'"
                  class="flex-shrink-0 px-1.5 py-0.5 text-xs rounded-full bg-n-blue-3 text-n-blue-11"
                >
                  {{ t('MANIFESTATION.LIST.NEW_BADGE') }}
                </span>
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-sm truncate text-n-slate-12">
                {{ item.title }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <Label
                :label="t(`MANIFESTATION.KINDS.${item.kind}`)"
                :color="kindColor(item.kind)"
                compact
              />
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-sm text-n-slate-11">
                {{ t(`MANIFESTATION.SUBJECT_AREAS.${item.subject_area}`) }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-sm truncate text-n-slate-11">
                {{ item.company_name || '—' }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <Label
                :label="t(`MANIFESTATION.STATUSES.${item.status}`)"
                :color="statusColor(item.status)"
                compact
              />
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-sm truncate text-n-slate-11">
                {{ item.assignee_name || t('MANIFESTATION.DETAIL.UNASSIGNED') }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-sm text-n-slate-11">
                {{ dataHora(item.created_at) }}
              </span>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </div>
  </div>
</template>
