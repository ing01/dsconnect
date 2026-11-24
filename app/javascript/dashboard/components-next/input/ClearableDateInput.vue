<script setup>
/**
 * Campo de data (`date` ou `datetime-local`) com um (x) para limpar.
 *
 * O (x) só aparece com valor e sem o campo desabilitado. Os demais atributos
 * (class, min, max, data-testid...) vão para o <input>, então ele substitui o
 * `<input type="date">` sem mudar o visual. `change` é reemitido (inclusive ao
 * limpar), para telas que buscam ao mudar a data.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  type: {
    type: String,
    default: 'date',
    validator: value => ['date', 'datetime-local'].includes(value),
  },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['change']);

defineOptions({ inheritAttrs: false });

const { t } = useI18n();
const value = defineModel({ type: String, default: '' });

const canClear = computed(() => Boolean(value.value) && !props.disabled);

const clear = () => {
  value.value = '';
  emit('change');
};
</script>

<template>
  <div class="relative flex min-w-0">
    <input
      v-bind="$attrs"
      v-model="value"
      :type="type"
      :disabled="disabled"
      class="grow min-w-0"
      :class="{ '!pr-16': canClear }"
      @change="emit('change', $event)"
    />
    <button
      v-if="canClear"
      type="button"
      class="absolute right-9 top-5 z-10 flex items-center justify-center -translate-y-1/2 rounded-full size-7 bg-n-alpha-3 text-n-slate-12 hover:bg-n-alpha-black2 hover:text-n-ruby-11 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-label="t('DATE_PICKER.CLEAR_DATE')"
      :title="t('DATE_PICKER.CLEAR_DATE')"
      data-testid="clear-date"
      @click.stop.prevent="clear"
    >
      <span class="block i-lucide-x size-5 shrink-0" aria-hidden="true" />
    </button>
  </div>
</template>
