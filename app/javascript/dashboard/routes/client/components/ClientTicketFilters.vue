<script setup>
/**
 * Os filtros da lista de chamados do cliente: Mesa, Estágio, Responsável,
 * status e período de abertura - os mesmos do app.
 *
 * As OPÇÕES vêm do servidor (só o que existe entre os chamados que o contato
 * pode ver); aqui só se escolhe. Como no app, Mesa só aparece havendo mais de
 * uma, e o Estágio é sempre o da Mesa escolhida - Mesas diferentes têm Estágios
 * com o MESMO nome (ex.: "Pendente"), e misturar tudo mostraria nomes repetidos
 * sem como distinguir.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, required: true },
  teams: { type: Array, default: () => [] },
  ticketColumns: { type: Array, default: () => [] },
  assignees: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue', 'clear']);

const { t } = useI18n();

// "open" é o padrão do servidor (sem status escolhido): não é uma opção, é a
// ausência de escolha - igual ao "Abertos (padrão)" do app.
const STATUSES = ['resolved', 'closed', 'cancelled'];

const SELECT_CLASS =
  'flex-shrink-0 h-8 px-2 mb-0 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12 max-w-48 disabled:opacity-60';

const showTeam = computed(() => props.teams.length > 1);

const columnOptions = computed(() =>
  showTeam.value
    ? props.ticketColumns.filter(
        column => column.team_id === props.modelValue.teamId
      )
    : props.ticketColumns
);

// Com várias Mesas, o Estágio só acende depois de escolher uma.
const columnDisabled = computed(
  () => showTeam.value && !props.modelValue.teamId
);

const hasFilters = computed(() =>
  Object.values(props.modelValue).some(
    value => value !== null && value !== undefined && value !== ''
  )
);

const update = changes => emit('update:modelValue', { ...props.modelValue, ...changes });

const toId = event => (event.target.value ? Number(event.target.value) : null);

// Trocar de Mesa limpa o Estágio: um Estágio de outra Mesa já não faz sentido.
const selectTeam = event => update({ teamId: toId(event), ticketColumnId: null });
const selectColumn = event => update({ ticketColumnId: toId(event) });
const selectAssignee = event => update({ assigneeId: toId(event) });
const selectStatus = event => update({ status: event.target.value || null });
const setDate = (field, event) => update({ [field]: event.target.value || null });
</script>

<template>
  <div class="flex flex-wrap items-center w-full gap-3 min-w-0">
    <select
      v-if="showTeam"
      :value="modelValue.teamId ?? ''"
      :class="SELECT_CLASS"
      :aria-label="t('CLIENT_AREA.BOARD.FILTERS.TEAM')"
      @change="selectTeam"
    >
      <option value="">{{ t('CLIENT_AREA.BOARD.FILTERS.ALL_TEAMS') }}</option>
      <option v-for="team in teams" :key="team.id" :value="team.id">
        {{ team.name }}
      </option>
    </select>

    <select
      v-if="ticketColumns.length"
      :value="modelValue.ticketColumnId ?? ''"
      :class="SELECT_CLASS"
      :disabled="columnDisabled"
      :title="
        columnDisabled ? t('CLIENT_AREA.BOARD.FILTERS.PICK_TEAM_FIRST') : ''
      "
      :aria-label="t('CLIENT_AREA.BOARD.FILTERS.COLUMN')"
      @change="selectColumn"
    >
      <option value="">
        {{
          columnDisabled
            ? t('CLIENT_AREA.BOARD.FILTERS.PICK_TEAM_FIRST')
            : t('CLIENT_AREA.BOARD.FILTERS.ALL_COLUMNS')
        }}
      </option>
      <option v-for="column in columnOptions" :key="column.id" :value="column.id">
        {{ column.name }}
      </option>
    </select>

    <select
      v-if="assignees.length"
      :value="modelValue.assigneeId ?? ''"
      :class="SELECT_CLASS"
      :aria-label="t('CLIENT_AREA.BOARD.FILTERS.ASSIGNEE')"
      @change="selectAssignee"
    >
      <option value="">{{ t('CLIENT_AREA.BOARD.FILTERS.ALL_ASSIGNEES') }}</option>
      <option v-for="assignee in assignees" :key="assignee.id" :value="assignee.id">
        {{ assignee.name }}
      </option>
    </select>

    <!-- Sem escolher, a lista só mostra chamados abertos; escolher um status é o
         jeito de achar um chamado já resolvido, finalizado ou cancelado. -->
    <select
      :value="modelValue.status ?? ''"
      :class="SELECT_CLASS"
      :aria-label="t('CLIENT_AREA.BOARD.STATUS')"
      @change="selectStatus"
    >
      <option value="">{{ t('CLIENT_AREA.BOARD.FILTERS.STATUS_DEFAULT') }}</option>
      <option v-for="status in STATUSES" :key="status" :value="status">
        {{ t(`TICKET.STATUS.${status.toUpperCase()}`) }}
      </option>
    </select>

    <label class="flex items-center gap-2 text-sm text-n-slate-11">
      {{ t('CLIENT_AREA.BOARD.FILTERS.OPENED_FROM') }}
      <input
        type="date"
        :value="modelValue.createdAfter ?? ''"
        :max="modelValue.createdBefore ?? ''"
        class="h-8 px-2 mb-0 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
        @change="setDate('createdAfter', $event)"
      />
    </label>

    <label class="flex items-center gap-2 text-sm text-n-slate-11">
      {{ t('CLIENT_AREA.BOARD.FILTERS.OPENED_UNTIL') }}
      <input
        type="date"
        :value="modelValue.createdBefore ?? ''"
        :min="modelValue.createdAfter ?? ''"
        class="h-8 px-2 mb-0 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12"
        @change="setDate('createdBefore', $event)"
      />
    </label>

    <button
      v-if="hasFilters"
      type="button"
      class="h-8 px-2 text-sm rounded-lg text-n-brand hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      @click="emit('clear')"
    >
      {{ t('CLIENT_AREA.BOARD.CLEAR_FILTERS') }}
    </button>
  </div>
</template>
