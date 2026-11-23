<script setup>
/**
 * Quantas conversas cada agente atendeu HOJE: as que resolveu no dia mais as que
 * estão com ele em atendimento agora. A barra divide o total do agente entre as
 * duas partes; o total do dia fecha o card.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  rows: { type: Array, default: () => [] },
});

const { t } = useI18n();

const dayTotal = computed(() =>
  props.rows.reduce((sum, row) => sum + row.total, 0)
);
const biggest = computed(() =>
  Math.max(1, ...props.rows.map(row => row.total))
);

const barWidth = row => `${(row.total / biggest.value) * 100}%`;
const part = (row, key) =>
  row.total ? `${(row[key] / row.total) * 100}%` : '0%';
</script>

<template>
  <section
    class="flex flex-col gap-3 p-4 border rounded-2xl border-n-weak bg-n-solid-2"
    data-testid="panel-handled-today"
  >
    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2">
        <h2 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t('CONVERSATION_PANEL.HANDLED.TITLE') }}
        </h2>
        <span
          class="text-xs font-semibold text-n-slate-12"
          data-testid="panel-handled-total"
        >
          {{ t('CONVERSATION_PANEL.HANDLED.DAY_TOTAL', { count: dayTotal }) }}
        </span>
      </div>
      <p class="m-0 text-xs text-n-slate-11">
        {{ t('CONVERSATION_PANEL.HANDLED.DESCRIPTION') }}
      </p>
      <div class="flex items-center gap-4 text-xs text-n-slate-11">
        <span class="flex items-center gap-1">
          <span class="rounded-full size-2.5 bg-n-blue-9" />
          {{ t('CONVERSATION_PANEL.HANDLED.RESOLVED') }}
        </span>
        <span class="flex items-center gap-1">
          <span class="rounded-full size-2.5 bg-n-teal-9" />
          {{ t('CONVERSATION_PANEL.HANDLED.IN_PROGRESS') }}
        </span>
      </div>
    </div>

    <p v-if="!rows.length" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_PANEL.HANDLED.EMPTY') }}
    </p>

    <ul class="flex flex-col gap-3 p-0 m-0 list-none">
      <li
        v-for="row in rows"
        :key="row.id"
        class="flex flex-col gap-1"
        :data-testid="`panel-handled-row-${row.id}`"
      >
        <div class="flex items-center justify-between gap-2 text-sm">
          <span class="font-medium truncate text-n-slate-12">
            {{ row.name }}
          </span>
          <span class="flex-shrink-0 text-xs text-n-slate-11">
            {{ t('CONVERSATION_PANEL.HANDLED.RESOLVED') }}: {{ row.resolved }} ·
            {{ t('CONVERSATION_PANEL.HANDLED.IN_PROGRESS') }}:
            {{ row.in_progress }} ·
            <strong class="text-n-slate-12">
              {{ t('CONVERSATION_PANEL.HANDLED.TOTAL', { count: row.total }) }}
            </strong>
          </span>
        </div>
        <div class="h-2.5 overflow-hidden rounded-full bg-n-alpha-2">
          <div class="flex h-full" :style="{ width: barWidth(row) }">
            <div
              class="h-full bg-n-blue-9"
              :style="{ width: part(row, 'resolved') }"
              :title="`${t('CONVERSATION_PANEL.HANDLED.RESOLVED')}: ${row.resolved}`"
            />
            <div
              class="h-full bg-n-teal-9"
              :style="{ width: part(row, 'in_progress') }"
              :title="`${t('CONVERSATION_PANEL.HANDLED.IN_PROGRESS')}: ${row.in_progress}`"
            />
          </div>
        </div>
      </li>
    </ul>
  </section>
</template>
