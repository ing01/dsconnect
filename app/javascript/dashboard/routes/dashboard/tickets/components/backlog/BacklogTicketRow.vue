<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import WootLabel from 'dashboard/components-next/label/Label.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { priorityColor } from '../../helpers/ticketLabels';

const props = defineProps({
  ticket: { type: Object, required: true },
  agents: { type: Array, default: () => [] },
  // Estagios da Mesa deste ticket - para o seletor inline. Vazio desliga o
  // seletor (fica so' o texto do Estagio atual, sem clicar pra trocar).
  columns: { type: Array, default: () => [] },
  selected: { type: Boolean, default: false },
});

const emit = defineEmits(['click', 'moveToColumn', 'toggleSelect']);

const { t } = useI18n();

const assignee = computed(
  () =>
    props.agents.find(agent => agent.id === props.ticket.assignee_id) || null
);

const priorityLabel = computed(() =>
  props.ticket.priority
    ? t(`TICKET.FORM.PRIORITY.${props.ticket.priority.toUpperCase()}`)
    : ''
);

// Estimativa original - campo do Modulo de Desenvolvimento, dentro de
// `custom_attributes`. So' aparece quando preenchida.
const estimateHours = computed(
  () => props.ticket.custom_attributes?.estimativa_original_horas
);

const currentColumn = computed(() =>
  props.columns.find(column => column.id === props.ticket.ticket_column_id)
);

const columnMenuItems = computed(() =>
  props.columns.map(column => ({
    label: column.name,
    value: column.id,
    action: 'selectColumn',
    isSelected: column.id === props.ticket.ticket_column_id,
  }))
);

const isColumnMenuOpen = ref(false);

const onColumnAction = ({ value }) => {
  isColumnMenuOpen.value = false;
  if (value !== props.ticket.ticket_column_id) {
    emit('moveToColumn', value);
  }
};
</script>

<template>
  <div
    class="drag-handle group flex items-center gap-2 rounded-lg border px-2.5 py-1.5 cursor-pointer hover:border-n-slate-6 hover:bg-n-slate-2 min-w-0"
    :class="
      selected ? 'border-n-brand bg-n-blue-2' : 'border-n-weak bg-n-solid-1'
    "
    @click="$emit('click', ticket)"
  >
    <Checkbox
      :model-value="selected"
      class="flex-shrink-0"
      @click.stop
      @change="emit('toggleSelect', ticket.id)"
    />

    <span
      v-if="ticket.display_id"
      class="text-xs text-n-slate-10 flex-shrink-0"
    >
      #{{ ticket.display_id }}
    </span>

    <p class="text-sm text-n-slate-12 truncate min-w-0 flex-1 m-0">
      {{ ticket.title }}
    </p>

    <!-- Estagio - pilula pequena, igual o seletor de status do Jira. So'
         vira menu quando a lista de Estagios da Mesa chegou. -->
    <OnClickOutside
      v-if="currentColumn"
      class="relative flex-shrink-0"
      @trigger="isColumnMenuOpen = false"
    >
      <button
        type="button"
        class="h-6 px-2 rounded-md text-xs font-medium border border-n-weak text-n-slate-11 hover:bg-n-slate-3 transition-colors"
        @click.stop="isColumnMenuOpen = !isColumnMenuOpen"
      >
        {{ currentColumn.name }}
      </button>
      <DropdownMenu
        v-if="isColumnMenuOpen"
        :menu-items="columnMenuItems"
        class="mt-1 top-full ltr:right-0 rtl:left-0 w-48 max-h-72"
        @click.stop
        @action="onColumnAction"
      />
    </OnClickOutside>

    <WootLabel
      v-if="ticket.priority"
      :label="priorityLabel"
      :color="priorityColor(ticket.priority)"
      compact
      class="flex-shrink-0"
    />

    <span
      v-if="estimateHours"
      class="flex items-center gap-1 text-xs text-n-slate-10 flex-shrink-0"
      :title="t('TICKET.DEVELOPMENT_FIELDS.ESTIMATIVA_HORAS')"
    >
      <Icon icon="i-lucide-clock" class="size-3" />
      {{ t('TICKET.BACKLOG.ESTIMATE_HOURS_SHORT', { hours: estimateHours }) }}
    </span>

    <Avatar
      v-if="assignee"
      v-tooltip="assignee.name"
      :name="assignee.name"
      :src="assignee.thumbnail"
      :size="20"
      rounded-full
      hide-offline-status
      class="flex-shrink-0"
    />
    <!-- Espaco reservado do mesmo tamanho do avatar, pra fileira nao "pular"
         de largura quando um ticket nao tem responsavel. -->
    <span v-else class="size-5 flex-shrink-0" />
  </div>
</template>
