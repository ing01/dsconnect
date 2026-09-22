<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import CompanyAPI from 'dashboard/api/companies';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  // Array of { id, name } - Empresas participantes do contrato (o mesmo
  // contrato pode cobrir varias, ver `ContactCompaniesField.vue` pro mesmo
  // padrao aplicado a Empresa->Contato).
  modelValue: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const options = ref([]);

const selectedIds = computed(
  () => new Set(props.modelValue.map(company => Number(company.id)))
);

const toOption = company => ({ label: company.name, value: company.id });

const comboboxOptions = computed(() =>
  options.value.filter(option => !selectedIds.value.has(Number(option.value)))
);

const fetchCompanies = async query => {
  try {
    const {
      data: { payload },
    } = query
      ? await CompanyAPI.search(query)
      : await CompanyAPI.get({ page: 1 });
    options.value = (payload || []).map(toOption);
  } catch {
    options.value = [];
  }
};

const handleOpen = () => fetchCompanies('');
const handleSearch = useDebounceFn(query => fetchCompanies(query?.trim() || ''), 300);

const addCompany = company => {
  if (selectedIds.value.has(Number(company.id))) return;
  emit('update:modelValue', [...props.modelValue, company]);
};

const removeCompany = id => {
  emit(
    'update:modelValue',
    props.modelValue.filter(company => Number(company.id) !== Number(id))
  );
};

const handleSelect = value => {
  const id = Number(value);
  const selected = options.value.find(option => option.value === id);
  if (selected) addCompany({ id, name: selected.label });
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div v-if="modelValue.length" class="flex flex-wrap gap-2">
      <span
        v-for="company in modelValue"
        :key="company.id"
        class="flex items-center h-7 gap-1 pl-2.5 pr-1 text-xs rounded-full bg-n-alpha-2 dark:bg-n-solid-3 text-n-slate-12"
      >
        {{ company.name }}
        <button
          type="button"
          class="flex items-center justify-center rounded-full size-4 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-ruby-11 i-lucide-x"
          :disabled="disabled"
          :aria-label="t('CONTRACTS.FORM.COMPANIES.REMOVE', { name: company.name })"
          @click="removeCompany(company.id)"
        />
      </span>
    </div>
    <ComboBox
      :options="comboboxOptions"
      :placeholder="t('CONTRACTS.FORM.COMPANIES.ADD_PLACEHOLDER')"
      :search-placeholder="t('CONTRACTS.FORM.COMPANIES.SEARCH_PLACEHOLDER')"
      :disabled="disabled"
      use-api-results
      class="[&>div>button]:h-8 [&>div>div_ul]:max-h-56"
      @open="handleOpen"
      @search="handleSearch"
      @update:model-value="handleSelect"
    />
  </div>
</template>
