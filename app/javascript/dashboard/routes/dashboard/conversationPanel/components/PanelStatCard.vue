<script setup>
/**
 * Um dos três cards do painel: número grande, quanto representa das abertas e
 * a maior espera da faixa. O card inteiro é clicável (abre a lista); o vermelho
 * pulsa de leve enquanto houver conversa nele.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { BANDS } from '../bands';
import { formatWait } from '../waitTime';

const props = defineProps({
  band: { type: String, required: true },
  count: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  hint: { type: String, default: '' },
  longestSeconds: { type: Number, default: null },
  isActive: { type: Boolean, default: false },
});

defineEmits(['select']);

const { t } = useI18n();
const style = computed(() => BANDS[props.band]);
const percent = computed(() =>
  props.total ? Math.round((props.count / props.total) * 100) : 0
);
const pulse = computed(() => props.band === 'red' && props.count > 0);
</script>

<template>
  <button
    type="button"
    class="flex flex-col gap-3 p-5 text-left transition-shadow border rounded-2xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    :class="[style.card, isActive ? style.cardActive : '']"
    :aria-pressed="isActive"
    :data-testid="`panel-card-${band}`"
    @click="$emit('select', band)"
  >
    <div class="flex items-center gap-3">
      <span
        class="relative flex items-center justify-center flex-shrink-0 rounded-full size-10"
        :class="style.iconWrap"
      >
        <span
          v-if="pulse"
          class="absolute inset-0 rounded-full animate-ping bg-n-ruby-9 opacity-40"
        />
        <Icon :icon="style.icon" class="relative size-5" />
      </span>
      <div class="flex flex-col min-w-0">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t(`CONVERSATION_PANEL.BANDS.${style.i18n}.TITLE`) }}
        </span>
        <span class="text-xs text-n-slate-11">{{ hint }}</span>
      </div>
    </div>

    <span
      class="text-6xl font-bold leading-none tabular-nums"
      :class="style.number"
      :data-testid="`panel-count-${band}`"
    >
      {{ count }}
    </span>

    <div class="flex flex-col gap-1">
      <div class="h-1.5 overflow-hidden rounded-full bg-n-alpha-2">
        <div
          class="h-full rounded-full"
          :class="style.bar"
          :style="{ width: `${percent}%` }"
        />
      </div>
      <span class="text-xs text-n-slate-11">
        <template v-if="count">
          {{ t('CONVERSATION_PANEL.CARD.OF_TOTAL', { percent }) }}
          <template v-if="longestSeconds !== null">
            ·
            {{
              t('CONVERSATION_PANEL.CARD.LONGEST', {
                time: formatWait(longestSeconds),
              })
            }}
          </template>
        </template>
        <template v-else>
          {{ t('CONVERSATION_PANEL.CARD.EMPTY') }}
        </template>
      </span>
    </div>
  </button>
</template>
