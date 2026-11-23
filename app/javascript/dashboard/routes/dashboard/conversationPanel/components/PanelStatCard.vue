<script setup>
/**
 * Um dos três cards do painel: número grande, quanto representa das abertas e
 * a maior espera da faixa. A área principal é clicável (abre a lista); o (!) no
 * canto explica, em português claro, o que o número representa; o vermelho
 * pulsa de leve enquanto houver conversa nele.
 */
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { BANDS } from '../bands';
import { formatWait } from '../waitTime';

const props = defineProps({
  band: { type: String, required: true },
  count: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  hint: { type: String, default: '' },
  info: { type: String, default: '' },
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

// O (!) abre ao passar o mouse, ao focar com o teclado ou ao clicar/tocar
// (celular e TV não têm "hover").
const isInfoOpen = ref(false);
const toggleInfo = () => {
  isInfoOpen.value = !isInfoOpen.value;
};
</script>

<template>
  <div
    class="relative flex flex-col transition-shadow border rounded-2xl"
    :class="[style.card, isActive ? style.cardActive : '']"
  >
    <button
      type="button"
      class="flex flex-col gap-3 p-5 text-left rounded-2xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-pressed="isActive"
      :data-testid="`panel-card-${band}`"
      @click="$emit('select', band)"
    >
      <div class="flex items-center gap-3 pr-8">
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

    <div
      v-if="info"
      class="absolute top-3 right-3"
      @mouseenter="isInfoOpen = true"
      @mouseleave="isInfoOpen = false"
    >
      <button
        type="button"
        class="flex items-center justify-center rounded-full size-7 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CONVERSATION_PANEL.CARD.INFO_LABEL')"
        :aria-expanded="isInfoOpen"
        :data-testid="`panel-info-${band}`"
        @click="toggleInfo"
        @focus="isInfoOpen = true"
        @blur="isInfoOpen = false"
      >
        <Icon icon="i-lucide-circle-alert" class="size-5" />
      </button>
      <div
        v-if="isInfoOpen"
        role="tooltip"
        class="absolute right-0 z-20 p-3 mt-1 text-sm leading-snug border shadow-lg w-72 rounded-xl border-n-weak bg-n-solid-3 text-n-slate-12"
        :data-testid="`panel-info-text-${band}`"
      >
        <p class="m-0 mb-1 font-semibold">
          {{ t('CONVERSATION_PANEL.CARD.INFO_LABEL') }}
        </p>
        <p class="m-0 text-n-slate-11">{{ info }}</p>
      </div>
    </div>
  </div>
</template>
