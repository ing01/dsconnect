<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import CompaniesAPI from 'dashboard/api/companies';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  modelValue: {
    type: [Number, String],
    default: null,
  },
  // Lets the field show the current Empresa of a ticket being edited without
  // waiting for a round-trip.
  initialName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue', 'select']);

const { t } = useI18n();

const isOpen = ref(false);
const isSearching = ref(false);
const companies = ref([]);
const selectedName = ref(props.initialName);

let searchToken = 0;

watch(
  () => props.initialName,
  name => {
    selectedName.value = name;
  }
);

watch(
  () => props.modelValue,
  id => {
    if (!id) selectedName.value = '';
  }
);

// Searching runs server-side against every Empresa in the account, so the list
// is never limited to whatever happened to be loaded on screen.
const loadCompanies = async (query = '') => {
  searchToken += 1;
  const token = searchToken;
  isSearching.value = true;
  try {
    const response = query
      ? await CompaniesAPI.search(query)
      : await CompaniesAPI.get({ page: 1 });
    // A slower earlier request must not overwrite a newer one's results.
    if (token !== searchToken) return;
    companies.value = response.data?.payload ?? [];
  } catch (error) {
    if (token === searchToken) companies.value = [];
  } finally {
    if (token === searchToken) isSearching.value = false;
  }
};

const openMenu = () => {
  isOpen.value = true;
  loadCompanies();
};

const menuItems = computed(() => [
  {
    label: t('TICKET.COMPANY.NONE'),
    value: null,
    action: 'clearCompany',
    isSelected: !props.modelValue,
  },
  ...companies.value.map(company => ({
    label: company.name,
    value: company.id,
    action: 'selectCompany',
    isSelected: Number(company.id) === Number(props.modelValue),
  })),
]);

const handleAction = ({ value, label }) => {
  isOpen.value = false;
  selectedName.value = value ? label : '';
  emit('update:modelValue', value);
  emit('select', value ? { id: value, name: label } : null);
};

const buttonLabel = computed(
  () => selectedName.value || t('TICKET.COMPANY.PLACEHOLDER')
);
</script>

<template>
  <OnClickOutside class="relative w-full" @trigger="isOpen = false">
    <button
      type="button"
      class="flex items-center justify-between w-full h-10 gap-2 px-3 text-sm border rounded-lg border-n-strong bg-n-alpha-black2 text-n-slate-12 hover:border-n-slate-8 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-label="t('TICKET.COMPANY.LABEL')"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="isOpen ? (isOpen = false) : openMenu()"
    >
      <span
        class="min-w-0 truncate ltr:text-left rtl:text-right"
        :class="selectedName ? 'text-n-slate-12' : 'text-n-slate-10'"
        :title="selectedName"
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
      show-search
      disable-local-filtering
      :is-searching="isSearching"
      :search-placeholder="t('TICKET.COMPANY.SEARCH')"
      empty-state-message="TICKET.COMPANY.EMPTY"
      class="mt-1 top-full ltr:left-0 rtl:right-0 w-full max-h-72"
      @search="loadCompanies"
      @action="handleAction"
    />
  </OnClickOutside>
</template>
