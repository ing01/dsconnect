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
import Icon from 'dashboard/components-next/icon/Icon.vue';

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
      :class="{ '!pr-14': canClear }"
      @change="emit('change', $event)"
    />
    <button
      v-if="canClear"
      type="button"
      class="absolute inset-y-0 flex items-center justify-center w-6 my-auto rounded-full right-8 h-6 text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2"
      :aria-label="t('DATE_PICKER.CLEAR_DATE')"
      :title="t('DATE_PICKER.CLEAR_DATE')"
      data-testid="clear-date"
      @click.stop.prevent="clear"
    >
      <Icon icon="i-lucide-x" class="size-3.5" />
    </button>
  </div>
</template>
