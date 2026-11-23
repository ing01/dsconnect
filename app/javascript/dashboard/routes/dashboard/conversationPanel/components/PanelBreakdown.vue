<script setup>
/**
 * Barras empilhadas (verde/laranja/vermelho) por agente ou por caixa de
 * entrada: mostra de relance quem está sobrecarregado e onde a espera cresce.
 */
import { useI18n } from 'vue-i18n';
import { BANDS } from '../bands';

defineProps({
  title: { type: String, required: true },
  rows: { type: Array, default: () => [] },
  // Nome mostrado quando a linha não tem dono (agente nulo).
  emptyName: { type: String, default: '' },
});

const { t } = useI18n();

const widthOf = (row, band) =>
  row.total ? `${(row[band] / row.total) * 100}%` : '0%';
</script>

<template>
  <section
    class="flex flex-col gap-3 p-4 border rounded-2xl border-n-weak bg-n-solid-2"
  >
    <h2 class="m-0 text-base font-semibold text-n-slate-12">{{ title }}</h2>

    <p v-if="!rows.length" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_PANEL.BREAKDOWN.EMPTY') }}
    </p>

    <ul class="flex flex-col gap-3 p-0 m-0 list-none">
      <li
        v-for="row in rows"
        :key="row.id ?? 'none'"
        class="flex flex-col gap-1"
      >
        <div class="flex items-center justify-between gap-2 text-sm">
          <span class="font-medium truncate text-n-slate-12">
            {{ row.name || emptyName }}
          </span>
          <span class="flex-shrink-0 text-xs text-n-slate-11">
            {{ t('CONVERSATION_PANEL.BREAKDOWN.TOTAL', { count: row.total }) }}
          </span>
        </div>
        <div class="flex h-2.5 overflow-hidden rounded-full bg-n-alpha-2">
          <div
            v-for="band in ['green', 'orange', 'red']"
            :key="band"
            :class="BANDS[band].bar"
            :style="{ width: widthOf(row, band) }"
            :title="`${row[band]}`"
          />
        </div>
      </li>
    </ul>
  </section>
</template>
