<script setup>
/**
 * O botão "Filtros" da lista de chamados do cliente e o modal onde eles se
 * escolhem: Mesa, Estágio, Responsável, status e período de abertura - os
 * mesmos do app.
 *
 * Nada é aplicado enquanto o modal está aberto: as escolhas ficam num rascunho e
 * só "Aplicar filtros" as entrega à lista (que busca de novo no servidor uma vez
 * só, e não a cada seletor mexido).
 *
 * As OPÇÕES vêm do servidor (só o que existe entre os chamados que o contato
 * pode ver). Como no app, Mesa só aparece havendo mais de uma, e o Estágio é
 * sempre o da Mesa escolhida - Mesas diferentes têm Estágios com o MESMO nome
 * (ex.: "Pendente"), e misturar tudo mostraria nomes repetidos sem como
 * distinguir.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketSelect from 'dashboard/routes/dashboard/tickets/components/TicketSelect.vue';
import { countActive, emptyFilters } from '../clientTicketFilters';

const props = defineProps({
  modelValue: { type: Object, required: true },
  teams: { type: Array, default: () => [] },
  ticketColumns: { type: Array, default: () => [] },
  assignees: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const dialog = ref(null);
const draft = ref(emptyFilters());

// "open" é o padrão do servidor (sem status escolhido): não é uma opção, é a
// ausência de escolha - igual ao "Abertos (padrão)" do app.
const STATUSES = ['resolved', 'closed', 'cancelled'];

const activeCount = computed(() => countActive(props.modelValue));

const toOptions = list => list.map(item => ({ value: item.id, label: item.name }));

const teamOptions = computed(() => toOptions(props.teams));
const assigneeOptions = computed(() => toOptions(props.assignees));
const statusOptions = computed(() =>
  STATUSES.map(status => ({
    value: status,
    label: t(`TICKET.STATUS.${status.toUpperCase()}`),
  }))
);

const showTeam = computed(() => props.teams.length > 1);

const columnOptions = computed(() =>
  toOptions(
    showTeam.value
      ? props.ticketColumns.filter(column => column.team_id === draft.value.teamId)
      : props.ticketColumns
  )
);

// Com várias Mesas, o Estágio só acende depois de escolher uma.
const columnDisabled = computed(() => showTeam.value && !draft.value.teamId);

// Trocar de Mesa limpa o Estágio: um Estágio de outra Mesa já não faz sentido.
const selectTeam = teamId => {
  draft.value = { ...draft.value, teamId, ticketColumnId: null };
};

const open = () => {
  draft.value = { ...emptyFilters(), ...props.modelValue };
  dialog.value?.open();
};

const apply = () => {
  emit('update:modelValue', { ...draft.value });
  dialog.value?.close();
};

const clearDraft = () => {
  draft.value = emptyFilters();
};

const DATE_CLASS =
  'w-full h-10 px-3 mb-0 text-sm border rounded-lg border-n-weak bg-n-solid-1 text-n-slate-12';
</script>

<template>
  <NextButton
    icon="i-lucide-list-filter"
    size="sm"
    color="slate"
    variant="faded"
    class="flex-shrink-0"
    :label="
      activeCount
        ? `${t('CLIENT_AREA.BOARD.FILTERS.BUTTON')} (${activeCount})`
        : t('CLIENT_AREA.BOARD.FILTERS.BUTTON')
    "
    @click="open"
  />

  <Dialog
    ref="dialog"
    type="edit"
    width="xl"
    :title="t('CLIENT_AREA.BOARD.FILTERS.TITLE')"
    :description="t('CLIENT_AREA.BOARD.FILTERS.DESCRIPTION')"
    :confirm-button-label="t('CLIENT_AREA.BOARD.FILTERS.APPLY')"
    @confirm="apply"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <!-- Duas colunas quando cabe; uma só no celular. -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <label v-if="showTeam" class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.BOARD.FILTERS.TEAM') }}
          </span>
          <TicketSelect
            :model-value="draft.teamId"
            :options="teamOptions"
            clearable
            :clear-label="t('CLIENT_AREA.BOARD.FILTERS.ALL_TEAMS')"
            :placeholder="t('CLIENT_AREA.BOARD.FILTERS.ALL_TEAMS')"
            class="w-full"
            @update:model-value="selectTeam"
          />
        </label>

        <label
          v-if="ticketColumns.length"
          class="flex flex-col gap-1 min-w-0"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.BOARD.FILTERS.COLUMN') }}
          </span>
          <TicketSelect
            v-model="draft.ticketColumnId"
            :options="columnOptions"
            :disabled="columnDisabled"
            clearable
            :clear-label="t('CLIENT_AREA.BOARD.FILTERS.ALL_COLUMNS')"
            :placeholder="
              columnDisabled
                ? t('CLIENT_AREA.BOARD.FILTERS.PICK_TEAM_FIRST')
                : t('CLIENT_AREA.BOARD.FILTERS.ALL_COLUMNS')
            "
            class="w-full"
          />
        </label>

        <label
          v-if="assignees.length"
          class="flex flex-col gap-1 min-w-0"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.BOARD.FILTERS.ASSIGNEE') }}
          </span>
          <TicketSelect
            v-model="draft.assigneeId"
            :options="assigneeOptions"
            clearable
            :clear-label="t('CLIENT_AREA.BOARD.FILTERS.ALL_ASSIGNEES')"
            :placeholder="t('CLIENT_AREA.BOARD.FILTERS.ALL_ASSIGNEES')"
            class="w-full"
          />
        </label>

        <!-- Sem escolher, a lista só mostra chamados abertos; escolher um status
             é o jeito de achar um chamado já resolvido, finalizado ou
             cancelado. -->
        <label class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CLIENT_AREA.BOARD.STATUS') }}
          </span>
          <TicketSelect
            v-model="draft.status"
            :options="statusOptions"
            clearable
            :clear-label="t('CLIENT_AREA.BOARD.FILTERS.STATUS_DEFAULT')"
            :placeholder="t('CLIENT_AREA.BOARD.FILTERS.STATUS_DEFAULT')"
            class="w-full"
          />
        </label>
      </div>

      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CLIENT_AREA.BOARD.FILTERS.PERIOD') }}
        </span>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-xs text-n-slate-11">
              {{ t('CLIENT_AREA.BOARD.FILTERS.OPENED_FROM') }}
            </span>
            <input
              v-model="draft.createdAfter"
              type="date"
              :max="draft.createdBefore || undefined"
              :class="DATE_CLASS"
            />
          </label>
          <label class="flex flex-col gap-1 min-w-0">
            <span class="text-xs text-n-slate-11">
              {{ t('CLIENT_AREA.BOARD.FILTERS.OPENED_UNTIL') }}
            </span>
            <input
              v-model="draft.createdBefore"
              type="date"
              :min="draft.createdAfter || undefined"
              :class="DATE_CLASS"
            />
          </label>
        </div>
      </div>

      <button
        type="button"
        class="self-start text-sm text-n-brand hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand rounded"
        @click="clearDraft"
      >
        {{ t('CLIENT_AREA.BOARD.CLEAR_FILTERS') }}
      </button>
    </div>
  </Dialog>
</template>
