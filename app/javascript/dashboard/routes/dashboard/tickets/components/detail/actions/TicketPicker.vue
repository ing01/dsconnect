<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import TicketsAPI from 'dashboard/api/tickets';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  modelValue: { type: [Number, String], default: null },
  placeholder: { type: String, default: '' },
  // Never offer the ticket the agent is already looking at: a ticket cannot be
  // its own parent, nor merged into itself.
  excludeId: { type: [Number, String], default: null },
  // Several at once, for callers that already hold a set of linked tickets.
  excludeIds: { type: Array, default: () => [] },
  // Merging into an already-closed ticket has no meaning, so the caller can
  // keep those out of the list rather than letting the server reject them.
  openOnly: { type: Boolean, default: false },
  // Restricts the list to one Empresa's tickets. Filtered server-side, so a
  // company with more tickets than one page still finds them.
  companyId: { type: [Number, String], default: null },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'select']);

const { t } = useI18n();

const isOpen = ref(false);
const isSearching = ref(false);
const tickets = ref([]);
const selected = ref(null);

let searchToken = 0;

// The server already matches both the ticket number and the title on `q`, so
// searching runs against every ticket in the account rather than whatever the
// Kanban happens to have loaded. Empresa and status narrow it server-side too -
// filtering a single page in the browser would silently hide the rest.
const searchParams = computed(() => {
  const params = {};
  if (props.companyId) params.company_id = props.companyId;
  if (props.openOnly) params.status = 'open';
  return params;
});

const loadTickets = async (query = '') => {
  searchToken += 1;
  const token = searchToken;
  isSearching.value = true;
  try {
    const response = await TicketsAPI.search(query, searchParams.value);
    // A slower earlier request must not overwrite a newer one's results.
    if (token !== searchToken) return;
    tickets.value = response.data?.payload ?? [];
  } catch (error) {
    if (token === searchToken) tickets.value = [];
  } finally {
    if (token === searchToken) isSearching.value = false;
  }
};

const options = computed(() =>
  tickets.value
    .filter(ticket => String(ticket.id) !== String(props.excludeId))
    .filter(
      ticket => !props.excludeIds.some(id => String(id) === String(ticket.id))
    )
    .filter(ticket => !props.openOnly || ticket.status === 'open')
    .filter(
      ticket =>
        !props.companyId ||
        String(ticket.company_id) === String(props.companyId)
    )
    .map(ticket => ({
      label: `#${ticket.display_id} - ${ticket.title}`,
      value: ticket.id,
      action: 'select',
      isSelected: String(ticket.id) === String(props.modelValue),
      // Shown under the label so two tickets with similar titles stay
      // distinguishable by their Empresa.
      description: ticket.company_name,
      ticket,
    }))
);

const openMenu = () => {
  if (props.disabled) return;
  isOpen.value = true;
  loadTickets();
};

const handleSelect = item => {
  selected.value = item.ticket;
  isOpen.value = false;
  emit('update:modelValue', item.value);
  emit('select', item.ticket);
};

watch(
  () => props.modelValue,
  value => {
    if (!value) selected.value = null;
  }
);

const label = computed(() =>
  selected.value
    ? `#${selected.value.display_id} - ${selected.value.title}`
    : props.placeholder || t('TICKET.ACTIONS.PICKER.PLACEHOLDER')
);
</script>

<template>
  <OnClickOutside class="relative w-full min-w-0" @trigger="isOpen = false">
    <button
      type="button"
      :disabled="disabled"
      class="flex items-center justify-between w-full h-10 gap-2 px-3 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 disabled:opacity-50 disabled:cursor-not-allowed"
      :class="{ 'text-n-slate-10': !selected }"
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
      :search-placeholder="t('TICKET.ACTIONS.PICKER.SEARCH')"
      empty-state-message="TICKET.ACTIONS.PICKER.EMPTY"
      class="mt-1 top-full w-full max-h-72"
      @search="loadTickets"
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
