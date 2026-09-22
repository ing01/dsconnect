<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import ContactAPI from 'dashboard/api/contacts';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  // The Contact id (Responsavel do contrato) - busca em toda a conta, o
  // contrato pode ter Empresas participantes diferentes, entao nao ha uma
  // unica Empresa pra travar a busca (diferente de `TicketContactSelect`).
  modelValue: { type: [String, Number], default: '' },
  responsibleName: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'select']);

const { t } = useI18n();

const options = ref([]);

const toOption = contact => ({
  label: contact.name || contact.email || `#${contact.id}`,
  value: contact.id,
});

const fetchContacts = async query => {
  try {
    const {
      data: { payload },
    } = await ContactAPI.search(query);
    options.value = (payload || []).map(toOption);
  } catch {
    options.value = [];
  }
};

const handleOpen = () => fetchContacts('');
const handleSearch = useDebounceFn(query => fetchContacts(query?.trim() || ''), 300);

const handleSelect = value => {
  const selected = options.value.find(option => option.value === Number(value));
  emit('update:modelValue', value);
  emit('select', selected ? { id: selected.value, name: selected.label } : null);
};
</script>

<template>
  <ComboBox
    :model-value="modelValue"
    :display-label="responsibleName"
    :options="options"
    :placeholder="t('CONTRACTS.FORM.RESPONSIBLE.PLACEHOLDER')"
    :search-placeholder="t('CONTRACTS.FORM.RESPONSIBLE.SEARCH_PLACEHOLDER')"
    :disabled="disabled"
    use-api-results
    @open="handleOpen"
    @search="handleSearch"
    @update:model-value="handleSelect"
  />
</template>
