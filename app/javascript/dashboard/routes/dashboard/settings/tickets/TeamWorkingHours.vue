<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  teamId: { type: Number, default: null },
  // O que o backend devolve: `working_hours_enabled`, `timezone` e a semana.
  workingHours: { type: Object, default: null },
});

const { t } = useI18n();
const store = useStore();

// Domingo a sábado, na ordem em que `day_of_week` os numera.
const DAYS = [0, 1, 2, 3, 4, 5, 6];

const isSaving = ref(false);
const draft = ref([]);

// Horas e minutos viajam separados no backend; a tela edita um `HH:MM` só.
const toTime = (hour, minutes) =>
  `${String(hour ?? 0).padStart(2, '0')}:${String(minutes ?? 0).padStart(2, '0')}`;

const parseTime = value => {
  const match = String(value ?? '').match(/^(\d{1,2}):([0-5]\d)$/);
  if (!match) return null;

  const hour = Number(match[1]);
  return hour <= 23 ? { hour, minutes: Number(match[2]) } : null;
};

const resetDraft = () => {
  const week = props.workingHours?.working_hours ?? [];
  draft.value = DAYS.map(day => {
    const stored = week.find(entry => entry.day_of_week === day) ?? {};
    return {
      day_of_week: day,
      closed: !!stored.closed_all_day,
      open: toTime(stored.open_hour ?? 9, stored.open_minutes ?? 0),
      close: toTime(stored.close_hour ?? 17, stored.close_minutes ?? 0),
    };
  });
};

watch(() => props.workingHours, resetDraft, { immediate: true, deep: true });

// Um dia fechado não precisa de horário válido; um dia aberto precisa dos dois,
// e o fechamento tem de vir depois da abertura — a mesma regra que o model impõe.
const rowError = row => {
  if (row.closed) return false;

  const open = parseTime(row.open);
  const close = parseTime(row.close);
  if (!open || !close) return true;

  return open.hour * 60 + open.minutes >= close.hour * 60 + close.minutes;
};

const hasError = computed(() => draft.value.some(rowError));

const save = async () => {
  if (hasError.value || isSaving.value || !props.teamId) return;

  isSaving.value = true;
  try {
    await store.dispatch('ticketColumns/updateWorkingHours', {
      teamId: props.teamId,
      working_hours: draft.value.map(row => {
        const open = parseTime(row.open) ?? { hour: 9, minutes: 0 };
        const close = parseTime(row.close) ?? { hour: 17, minutes: 0 };
        return {
          day_of_week: row.day_of_week,
          closed_all_day: row.closed,
          open_all_day: false,
          open_hour: open.hour,
          open_minutes: open.minutes,
          close_hour: close.hour,
          close_minutes: close.minutes,
        };
      }),
    });
    useAlert(t('TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.SAVED'));
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-3 min-w-0">
    <h3 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.TITLE') }}
    </h3>

    <div
      v-for="row in draft"
      :key="row.day_of_week"
      class="flex flex-wrap items-center gap-3 min-w-0"
    >
      <span class="w-28 text-sm text-n-slate-11">
        {{
          t(`TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.DAYS.D${row.day_of_week}`)
        }}
      </span>

      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input v-model="row.closed" type="checkbox" class="m-0" />
        {{ t('TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.CLOSED') }}
      </label>

      <template v-if="!row.closed">
        <input
          v-model="row.open"
          type="text"
          class="w-24 mb-0"
          :class="{ error: rowError(row) }"
          :placeholder="t('TICKET.SETTINGS.FORM.STAGE_SLA.PLACEHOLDER')"
        />
        <span class="text-sm text-n-slate-11">
          {{ t('TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.TO') }}
        </span>
        <input
          v-model="row.close"
          type="text"
          class="w-24 mb-0"
          :class="{ error: rowError(row) }"
          :placeholder="t('TICKET.SETTINGS.FORM.STAGE_SLA.PLACEHOLDER')"
        />
      </template>
    </div>

    <div class="flex justify-end">
      <Button
        faded
        slate
        :label="t('TICKET.SETTINGS.PRIORITIES.WORKING_HOURS.SAVE')"
        :disabled="hasError || !teamId"
        :is-loading="isSaving"
        @click="save"
      />
    </div>
  </div>
</template>
