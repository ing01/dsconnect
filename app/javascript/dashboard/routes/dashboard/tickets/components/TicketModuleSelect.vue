<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { moduleFromTitle, withModule } from '../helpers/titleModule';
import TicketSelect from './TicketSelect.vue';

// O modulo do sistema (DS Comercial...) vem do Catalogo de Servicos, 1o nivel, e entra no
// comeco do titulo como "[Modulo] ". O v-model e' o proprio TITULO: o modulo escolhido e'
// lido dele, sem estado a parte, entao nunca fica fora de sincronia com o texto.
const props = defineProps({
  modelValue: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const store = useStore();

const catalogs = useMapGetter('serviceCatalogs/getActiveCatalogs');
const names = computed(() => catalogs.value.map(item => item.name));
const options = computed(() =>
  names.value.map(name => ({ value: name, label: name }))
);

const selected = computed({
  get: () => moduleFromTitle(props.modelValue, names.value),
  set: name =>
    emit('update:modelValue', withModule(props.modelValue, name, names.value)),
});

// O catalogo muda nas Configuracoes: busca ao abrir, e nao uma vez so.
onMounted(() => store.dispatch('serviceCatalogs/fetch'));
</script>

<template>
  <div v-if="options.length" class="sm:w-56 sm:flex-shrink-0 min-w-0">
    <TicketSelect
      v-model="selected"
      :options="options"
      clearable
      show-search
      :search-placeholder="t('TICKET.FORM.TITLE.MODULE_SEARCH')"
      :clear-label="t('TICKET.FORM.TITLE.NO_MODULE')"
      :placeholder="t('TICKET.FORM.TITLE.MODULE_PLACEHOLDER')"
      :aria-label="t('TICKET.FORM.TITLE.MODULE_LABEL')"
    />
  </div>
</template>
