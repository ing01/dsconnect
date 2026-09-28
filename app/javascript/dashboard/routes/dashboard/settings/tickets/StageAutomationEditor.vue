<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { formatMesaName } from 'dashboard/helper/mesaName';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
  // So usado pela acao 'move_parent_to_column' (Mesa -> Estagio do ticket pai) -
  // as demais acoes nao precisam saber de outras Mesas alem da atual.
  teams: {
    type: Array,
    default: () => [],
  },
});
const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const store = useStore();

// Mesma lista de TicketColumn::AUTOMATION_ACTION_TYPES no backend - a
// validacao de verdade mora la, esta so decide o que a tela oferece.
const ACTION_TYPES = [
  'set_priority',
  'set_status',
  'set_assignee',
  'clear_due_date',
  'clear_scheduled_at',
  'post_note',
  'move_parent_to_column',
];
const PRIORITY_OPTIONS = ['low', 'medium', 'high', 'urgent'];
const STATUS_OPTIONS = ['open', 'resolved', 'closed', 'cancelled'];
const DEFAULT_VALUE_FOR_TYPE = {
  set_priority: 'medium',
  set_status: 'resolved',
  set_assignee: '',
  clear_due_date: null,
  clear_scheduled_at: null,
  post_note: '',
  move_parent_to_column: { team_id: null, ticket_column_id: null },
};

const actions = computed(() => props.modelValue || []);

const update = next => emit('update:modelValue', next);

const addAction = () => {
  update([...actions.value, { type: 'set_priority', value: 'medium' }]);
};

const removeAction = index => {
  update(actions.value.filter((_, position) => position !== index));
};

const setType = (index, type) => {
  update(
    actions.value.map((action, position) =>
      position === index ? { type, value: DEFAULT_VALUE_FOR_TYPE[type] } : action
    )
  );
};

const setValue = (index, value) => {
  update(
    actions.value.map((action, position) =>
      position === index ? { ...action, value } : action
    )
  );
};

const actionLabel = type =>
  t(`TICKET.SETTINGS.FORM.AUTOMATION.ACTION_TYPES.${type.toUpperCase()}`);
const actionHint = type =>
  t(`TICKET.SETTINGS.FORM.AUTOMATION.ACTION_HINTS.${type.toUpperCase()}`);

// Colunas (Estagios) da Mesa escolhida em CADA acao 'move_parent_to_column' -
// cada acao tem sua propria Mesa/Estagio, entao a busca e por `teamId`, nao
// por uma unica selecao global de tela.
const columnsForTeam = teamId =>
  store.getters['ticketColumns/getColumns'](teamId) || [];

const onParentColumnTeamChange = async (index, teamId) => {
  await store.dispatch('ticketColumns/fetchColumns', teamId);
  const firstColumnId = columnsForTeam(teamId)[0]?.id || null;
  setValue(index, { team_id: teamId || null, ticket_column_id: firstColumnId });
};

const onParentColumnChange = (index, ticketColumnId) => {
  const action = actions.value[index];
  setValue(index, { ...action.value, ticket_column_id: ticketColumnId || null });
};

// Ao abrir o editor com uma acao ja configurada, busca a Mesa que ela ja
// aponta - senao o select de Estagio nasceria vazio ate a pessoa trocar de Mesa.
onMounted(() => {
  actions.value
    .filter(action => action.type === 'move_parent_to_column' && action.value?.team_id)
    .forEach(action => store.dispatch('ticketColumns/fetchColumns', action.value.team_id));
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      v-for="(action, index) in actions"
      :key="index"
      class="flex flex-col gap-2 p-2 border rounded-lg border-n-weak"
    >
      <div class="flex items-center gap-2">
        <select
          :value="action.type"
          class="mb-0"
          @change="setType(index, $event.target.value)"
        >
          <option v-for="type in ACTION_TYPES" :key="type" :value="type">
            {{ actionLabel(type) }}
          </option>
        </select>
        <NextButton
          v-tooltip.top="t('TICKET.SETTINGS.FORM.AUTOMATION.REMOVE_ACTION')"
          type="button"
          ruby
          ghost
          xs
          icon="i-lucide-trash-2"
          @click="removeAction(index)"
        />
      </div>

      <select
        v-if="action.type === 'set_priority'"
        :value="action.value"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option
          v-for="option in PRIORITY_OPTIONS"
          :key="option"
          :value="option"
        >
          {{ t(`TICKET.FORM.PRIORITY.${option.toUpperCase()}`) }}
        </option>
      </select>

      <select
        v-else-if="action.type === 'set_status'"
        :value="action.value"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option v-for="option in STATUS_OPTIONS" :key="option" :value="option">
          {{ t(`TICKET.STATUS.${option.toUpperCase()}`) }}
        </option>
      </select>

      <select
        v-else-if="action.type === 'set_assignee'"
        :value="action.value || ''"
        class="mb-0"
        @change="setValue(index, $event.target.value)"
      >
        <option value="">
          {{ t('TICKET.SETTINGS.FORM.AUTOMATION.UNASSIGN') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>

      <textarea
        v-else-if="action.type === 'post_note'"
        :value="action.value"
        rows="2"
        class="mb-0"
        :placeholder="t('TICKET.SETTINGS.FORM.AUTOMATION.NOTE_PLACEHOLDER')"
        @input="setValue(index, $event.target.value)"
      />

      <div
        v-else-if="action.type === 'move_parent_to_column'"
        class="flex flex-col gap-2"
      >
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('TICKET.SETTINGS.FORM.AUTOMATION.ACTION_HINTS.MOVE_PARENT_TO_COLUMN') }}
        </p>
        <div class="flex items-center gap-2">
          <select
            :value="action.value?.team_id || ''"
            class="mb-0"
            @change="onParentColumnTeamChange(index, $event.target.value)"
          >
            <option value="" disabled>
              {{ t('TICKET.SETTINGS.FORM.MESA.LABEL') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ formatMesaName(team.name) }}
            </option>
          </select>
          <select
            :value="action.value?.ticket_column_id || ''"
            class="mb-0"
            :disabled="!action.value?.team_id"
            @change="onParentColumnChange(index, $event.target.value)"
          >
            <option value="" disabled>
              {{ t('TICKET.SETTINGS.FORM.AUTOMATION.STAGE_LABEL') }}
            </option>
            <option
              v-for="column in columnsForTeam(action.value?.team_id)"
              :key="column.id"
              :value="column.id"
            >
              {{ column.name }}
            </option>
          </select>
        </div>
      </div>

      <p v-else class="mb-0 text-xs text-n-slate-11">
        {{ actionHint(action.type) }}
      </p>
    </div>

    <NextButton
      type="button"
      slate
      faded
      sm
      icon="i-lucide-plus"
      :label="t('TICKET.SETTINGS.FORM.AUTOMATION.ADD_ACTION')"
      @click="addAction"
    />
  </div>
</template>
