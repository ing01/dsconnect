<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

/**
 * O seletor padrão do módulo de Tickets.
 *
 * O visual saiu do campo Empresa, que já era o mais completo; em vez de copiar
 * aquele HTML para cada campo, ele virou este componente. Todo select do módulo
 * passa por aqui, então mudar o padrão é mudar um arquivo só.
 *
 * Faz os dois modos com a mesma aparência: escolha única e escolha múltipla. No
 * múltiplo o menu não fecha a cada clique, porque escolher três pessoas não
 * deveria custar três aberturas.
 */
const props = defineProps({
  // Um valor no modo simples; um array de valores no múltiplo.
  modelValue: { type: [Number, String, Array], default: null },
  options: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  ariaLabel: { type: String, default: '' },
  multiple: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  // Campo em erro: a borda muda para destacar o que falta preencher. Padrao
  // `false`, entao nenhum uso existente muda.
  hasError: { type: Boolean, default: false },
  // A busca dentro do menu só aparece quando pedida - listas curtas não
  // precisam dela.
  showSearch: { type: Boolean, default: false },
  searchPlaceholder: { type: String, default: '' },
  isSearching: { type: Boolean, default: false },
  // Para buscas que acontecem no servidor, onde filtrar no navegador
  // esconderia resultados que ainda não chegaram.
  disableLocalFiltering: { type: Boolean, default: false },
  emptyMessage: { type: String, default: 'DROPDOWN_MENU.EMPTY_STATE' },
  // Oferece uma opção para esvaziar o campo, como "Nenhuma empresa".
  clearable: { type: Boolean, default: false },
  clearLabel: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue', 'search', 'select']);

const { t } = useI18n();

const isOpen = ref(false);

const selectedValues = computed(() => {
  if (!props.multiple)
    return props.modelValue == null ? [] : [props.modelValue];
  return Array.isArray(props.modelValue) ? props.modelValue : [];
});

const isChosen = value =>
  selectedValues.value.some(item => String(item) === String(value));

const selectedOptions = computed(() =>
  props.options.filter(option => isChosen(option.value))
);

/**
 * O rótulo do botão. No múltiplo cabem dois nomes e o resto vira `+n`, para
 * que o campo não cresça nem esconda que há mais escolhas.
 */
const buttonLabel = computed(() => {
  const chosen = selectedOptions.value;
  if (!chosen.length) return props.placeholder;
  if (!props.multiple) return chosen[0].label;

  const shown = chosen
    .slice(0, 2)
    .map(option => option.label)
    .join(', ');
  const rest = chosen.length - 2;
  return rest > 0 ? `${shown} +${rest}` : shown;
});

const hasSelection = computed(() => selectedOptions.value.length > 0);

// No múltiplo o ícone é a caixa de marcação; no simples, o que a opção trouxer.
const iconFor = option => {
  if (!props.multiple) return option.icon;
  return isChosen(option.value) ? 'i-lucide-square-check' : 'i-lucide-square';
};

const menuItems = computed(() => {
  const items = props.options.map(option => ({
    ...option,
    icon: iconFor(option),
    isSelected: isChosen(option.value),
    action: 'select',
  }));

  if (!props.clearable || props.multiple) return items;

  return [
    {
      label: props.clearLabel || t('DROPDOWN_MENU.EMPTY_STATE'),
      value: null,
      action: 'select',
      isSelected: !hasSelection.value,
    },
    ...items,
  ];
});

const toggle = () => {
  if (props.disabled) return;
  isOpen.value = !isOpen.value;
};

const handleAction = item => {
  if (!props.multiple) {
    isOpen.value = false;
    emit('update:modelValue', item.value);
    emit('select', item.value == null ? null : item);
    return;
  }

  // Múltiplo: alterna o valor e mantém o menu aberto.
  const next = isChosen(item.value)
    ? selectedValues.value.filter(value => String(value) !== String(item.value))
    : [...selectedValues.value, item.value];

  emit('update:modelValue', next);
  emit('select', next);
};

// Fechar o menu limpa a busca do consumidor, que costuma ser feita no servidor.
watch(isOpen, open => {
  if (!open && props.disableLocalFiltering) emit('search', '');
});

const close = () => {
  isOpen.value = false;
};

defineExpose({ close });
</script>

<template>
  <OnClickOutside class="relative w-full" @trigger="isOpen = false">
    <button
      type="button"
      class="flex items-center justify-between w-full h-10 gap-2 px-3 text-sm border rounded-lg bg-n-alpha-black2 text-n-slate-12 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-50 disabled:cursor-not-allowed"
      :class="
        hasError
          ? 'border-n-ruby-8 hover:border-n-ruby-9'
          : 'border-n-strong hover:border-n-slate-8'
      "
      :aria-label="ariaLabel || undefined"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      :disabled="disabled"
      @click="toggle"
    >
      <span
        class="min-w-0 truncate ltr:text-left rtl:text-right"
        :class="hasSelection ? 'text-n-slate-12' : 'text-n-slate-10'"
        :title="hasSelection ? buttonLabel : undefined"
      >
        {{ buttonLabel }}
      </span>
      <Icon
        :icon="isOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        class="shrink-0 text-n-slate-11"
      />
    </button>

    <DropdownMenu
      v-if="isOpen"
      :menu-items="menuItems"
      :show-search="showSearch"
      :disable-local-filtering="disableLocalFiltering"
      :is-searching="isSearching"
      :search-placeholder="searchPlaceholder"
      :empty-state-message="emptyMessage"
      class="mt-1 top-full ltr:left-0 rtl:right-0 w-full max-h-72"
      @search="value => emit('search', value)"
      @action="handleAction"
    />
  </OnClickOutside>
</template>
