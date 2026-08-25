<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import CompaniesAPI from 'dashboard/api/companies';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  modelValue: { type: [Number, String], default: null },
  // The Solicitante is a person AT the Empresa, so the list comes from the
  // company's own contacts. Without an Empresa there is nothing to list.
  companyId: { type: [Number, String], default: null },
  // Lets the field show the ticket's current Solicitante without waiting for a
  // round-trip.
  initialName: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue', 'select']);

const { t } = useI18n();

const isOpen = ref(false);
const isSearching = ref(false);
const contacts = ref([]);
const selectedName = ref(props.initialName);

let searchToken = 0;

const isDisabled = computed(() => !props.companyId);

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

// Changing the Empresa invalidates the whole list, and whatever was picked from
// the previous one.
watch(
  () => props.companyId,
  (id, previous) => {
    contacts.value = [];
    if (previous === undefined || id === previous) return;
    selectedName.value = '';
    emit('update:modelValue', null);
  }
);

// Filtering happens server-side against the company's contacts, so a company
// with more contacts than one page still finds them.
const loadContacts = async (query = '') => {
  if (!props.companyId) return;

  searchToken += 1;
  const token = searchToken;
  isSearching.value = true;
  try {
    const response = await CompaniesAPI.listContacts(props.companyId, 1, query);
    // A slower earlier request must not overwrite a newer one's results.
    if (token !== searchToken) return;
    contacts.value = response.data?.payload ?? [];
  } catch (error) {
    if (token === searchToken) contacts.value = [];
  } finally {
    if (token === searchToken) isSearching.value = false;
  }
};

const options = computed(() =>
  contacts.value.map(contact => ({
    label: contact.name || contact.email || `#${contact.id}`,
    value: contact.id,
    action: 'select',
    isSelected: String(contact.id) === String(props.modelValue),
    // Two contacts often share a first name; the e-mail is what tells them
    // apart.
    description: contact.email || contact.phone_number,
    contact,
  }))
);

const openMenu = () => {
  if (isDisabled.value) return;
  isOpen.value = true;
  loadContacts();
};

const handleSelect = item => {
  selectedName.value = item.label;
  isOpen.value = false;
  emit('update:modelValue', item.value);
  emit('select', item.contact);
};

const label = computed(() => {
  if (isDisabled.value) return t('TICKET.ACTIONS.CONTACT_DIALOG.NEEDS_COMPANY');
  return selectedName.value || t('TICKET.ACTIONS.CONTACT_DIALOG.PLACEHOLDER');
});
</script>

<template>
  <OnClickOutside class="relative w-full min-w-0" @trigger="isOpen = false">
    <button
      type="button"
      :disabled="isDisabled"
      class="flex items-center justify-between w-full h-10 gap-2 px-3 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 disabled:opacity-50 disabled:cursor-not-allowed"
      :class="{ 'text-n-slate-10': !selectedName }"
      @click="openMenu"
    >
      <span class="truncate min-w-0 text-left">{{ label }}</span>
      <Icon icon="i-lucide-chevron-down" class="flex-shrink-0 size-4" />
    </button>

    <DropdownMenu
      v-if="isOpen"
      show-search
      disable-local-filtering
      :is-searching="isSearching"
      :menu-items="options"
      :search-placeholder="t('TICKET.ACTIONS.CONTACT_DIALOG.SEARCH')"
      empty-state-message="TICKET.ACTIONS.CONTACT_DIALOG.EMPTY"
      class="mt-1 top-full w-full max-h-72"
      @search="loadContacts"
      @action="handleSelect"
    >
      <template #label="{ item }">
        <span class="flex flex-col min-w-0 text-left">
          <span class="text-sm truncate font-420">{{ item.label }}</span>
          <span
            v-if="item.description"
            class="text-xs truncate text-n-slate-10"
          >
            {{ item.description }}
          </span>
        </span>
      </template>
    </DropdownMenu>
  </OnClickOutside>
</template>
