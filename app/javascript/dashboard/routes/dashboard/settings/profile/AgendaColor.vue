<script setup>
/**
 * Cor que identifica a pessoa na Agenda: os eventos criados por ela e o ponto
 * ao lado do nome dela usam essa cor, para todos que veem a agenda. Sem
 * escolha, vale a cor automática.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { EVENT_COLOR_OPTIONS } from 'dashboard/components-next/Agenda/constants';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  // Cor escolhida (#rrggbb) ou vazio para a automática.
  value: { type: String, default: '' },
  // Cor automática, mostrada quando não há escolha.
  automaticColor: { type: String, default: '' },
});

const emit = defineEmits(['change']);

const { t } = useI18n();

const current = computed(() => props.value || props.automaticColor);
const isSame = (a, b) => (a || '').toLowerCase() === (b || '').toLowerCase();
const customColor = computed(() =>
  props.value && !EVENT_COLOR_OPTIONS.some(color => isSame(color, props.value))
    ? props.value
    : current.value
);

const pick = color => emit('change', color);
const onCustom = event => pick(event.target.value);
</script>

<template>
  <div class="flex flex-col gap-3 w-full">
    <div class="flex flex-wrap items-center gap-2" role="radiogroup">
      <button
        v-for="color in EVENT_COLOR_OPTIONS"
        :key="color"
        type="button"
        role="radio"
        class="rounded-full size-8 border-2 transition-shadow"
        :class="
          isSame(color, current)
            ? 'border-n-slate-12 ring-2 ring-n-brand'
            : 'border-transparent'
        "
        :style="{ backgroundColor: color }"
        :aria-checked="isSame(color, current)"
        :aria-label="color"
        :data-testid="`agenda-color-${color.slice(1)}`"
        @click="pick(color)"
      />
      <label
        class="flex items-center gap-2 ml-2 text-sm text-n-slate-11 cursor-pointer"
      >
        <input
          type="color"
          class="p-0 border-0 rounded-full size-8 bg-transparent cursor-pointer"
          :value="customColor"
          data-testid="agenda-color-custom"
          @change="onCustom"
        />
        {{ t('PROFILE_SETTINGS.FORM.AGENDA_COLOR.CUSTOM') }}
      </label>
    </div>
    <NextButton
      v-if="value"
      slate
      faded
      sm
      class="self-start"
      data-testid="agenda-color-reset"
      :label="t('PROFILE_SETTINGS.FORM.AGENDA_COLOR.RESET')"
      @click="pick('')"
    />
  </div>
</template>
