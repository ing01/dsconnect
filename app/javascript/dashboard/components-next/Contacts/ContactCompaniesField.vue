<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import CompanyAPI from 'dashboard/api/companies';
import { useAlert } from 'dashboard/composables';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import CompanyCreateDialog from 'dashboard/components-next/Companies/CompanyCreateDialog.vue';

const props = defineProps({
  // Array of { id, name } - a contact can work at more than one Empresa.
  modelValue: {
    type: Array,
    default: () => [],
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const CREATE_PREFIX = 'create:';

const options = ref([]);
const searchQuery = ref('');
const createDialogRef = ref(null);
const isCreatingCompany = ref(false);

const selectedIds = computed(
  () => new Set(props.modelValue.map(company => Number(company.id)))
);

const toOption = company => ({ label: company.name, value: company.id });

const createOption = computed(() => {
  const name = searchQuery.value.trim();
  if (!name) return null;

  const exists = options.value.some(
    option => option.label.toLowerCase() === name.toLowerCase()
  );
  if (exists) return null;

  return {
    label: t('COMPANIES.SELECTOR.CREATE_OPTION', { name }),
    value: `${CREATE_PREFIX}${name}`,
  };
});

const comboboxOptions = computed(() => {
  const list = options.value.filter(
    option => !selectedIds.value.has(Number(option.value))
  );
  if (createOption.value) list.push(createOption.value);
  return list;
});

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

// Fetch lazily, only when the dropdown opens, instead of on mount.
const handleOpen = () => {
  searchQuery.value = '';
  fetchCompanies('');
};

const handleSearch = useDebounceFn(query => {
  searchQuery.value = query?.trim() || '';
  fetchCompanies(searchQuery.value);
}, 300);

const addCompany = company => {
  if (selectedIds.value.has(Number(company.id))) return;
  emit('update:modelValue', [
    ...props.modelValue,
    { id: Number(company.id), name: company.name },
  ]);
};

const removeCompany = id => {
  emit(
    'update:modelValue',
    props.modelValue.filter(company => Number(company.id) !== Number(id))
  );
};

// Open the create dialog (prefilled with the typed name) so the user can add
// domain/description before saving, instead of creating with just a name.
const createCompany = async company => {
  isCreatingCompany.value = true;
  try {
    const {
      data: { payload },
    } = await CompanyAPI.create({ company });
    createDialogRef.value?.onSuccess();
    addCompany(payload);
    useAlert(t('COMPANIES.CREATE.MESSAGES.SUCCESS'));
  } catch {
    useAlert(t('COMPANIES.CREATE.MESSAGES.ERROR'));
  } finally {
    isCreatingCompany.value = false;
  }
};

const handleSelect = value => {
  if (typeof value === 'string' && value.startsWith(CREATE_PREFIX)) {
    createDialogRef.value?.open({ name: value.slice(CREATE_PREFIX.length) });
    // Drop the transient "Add …" option so the button label doesn't stick to
    // it if the dialog is dismissed without creating.
    searchQuery.value = '';
    return;
  }

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
          :aria-label="t('COMPANIES.SELECTOR.REMOVE', { name: company.name })"
          @click="removeCompany(company.id)"
        />
      </span>
    </div>
    <ComboBox
      :options="comboboxOptions"
      :placeholder="t('COMPANIES.SELECTOR.ADD_ANOTHER_PLACEHOLDER')"
      :search-placeholder="t('COMPANIES.SEARCH_PLACEHOLDER')"
      :disabled="disabled"
      use-api-results
      class="[&>div>button]:h-8 [&>div>div_ul]:max-h-56"
      @open="handleOpen"
      @search="handleSearch"
      @update:model-value="handleSelect"
    />
    <CompanyCreateDialog
      ref="createDialogRef"
      :is-loading="isCreatingCompany"
      @create="createCompany"
    />
  </div>
</template>
