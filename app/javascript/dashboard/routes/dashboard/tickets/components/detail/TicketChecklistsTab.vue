<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import OpenChecklistSettingsButton from 'dashboard/components-next/checklist/OpenChecklistSettingsButton.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();

const selectedChecklistId = ref('');
const isSubmitting = ref(false);

const items = computed(
  () =>
    store.getters['ticketChecklistItems/getItemsByTicket'](props.ticketId) ||
    []
);
const checklists = computed(
  () => store.getters['checklists/getChecklists'] || []
);

const pendingCount = computed(
  () => items.value.filter(item => !item.completed).length
);

const load = () => {
  store.dispatch('ticketChecklistItems/getByTicket', props.ticketId);
  store.dispatch('checklists/get');
};

// Attaching copies every item of the chosen Checklist onto this ticket - it
// can be done more than once, and with different Checklists, over the
// ticket's lifecycle (see TicketChecklistItemsController#attach_checklist).
const attachChecklist = async () => {
  if (!selectedChecklistId.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await store.dispatch('ticketChecklistItems/attachChecklist', {
      ticketId: props.ticketId,
      checklistId: selectedChecklistId.value,
    });
    selectedChecklistId.value = '';
  } catch (error) {
    useAlert(t('TICKET.DETAIL.CHECKLISTS.ADD_ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const toggleItem = async item => {
  try {
    await store.dispatch('ticketChecklistItems/toggle', {
      ticketId: props.ticketId,
      itemId: item.id,
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.CHECKLISTS.TOGGLE_ERROR'));
  }
};

const removeItem = async item => {
  try {
    await store.dispatch('ticketChecklistItems/delete', {
      ticketId: props.ticketId,
      itemId: item.id,
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.CHECKLISTS.DELETE_ERROR'));
  }
};

onMounted(load);
watch(() => props.ticketId, load);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <div class="flex items-center justify-between">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('TICKET.DETAIL.CHECKLISTS.TITLE') }}
      </h2>
      <OpenChecklistSettingsButton />
    </div>

    <!-- The completion lock (Ticket#ensure_checklist_completed!) is bypassed by
         a linked Apontamento, so this is a hint rather than a hard blocker
         here - the Fechar dialog is the one place that reflects the server's
         actual verdict. -->
    <p
      v-if="pendingCount"
      class="flex items-center gap-2 text-sm text-n-amber-11 bg-n-amber-3 rounded-lg px-3 py-2"
    >
      <Icon icon="i-lucide-triangle-alert" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.CHECKLISTS.PENDING_HINT') }}
    </p>

    <p
      v-if="!items.length"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-list-checks" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.CHECKLISTS.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-1">
      <li
        v-for="item in items"
        :key="item.id"
        class="group flex items-center gap-2 px-1 py-1 rounded-lg min-w-0"
      >
        <input
          type="checkbox"
          :checked="item.completed"
          class="flex-shrink-0"
          @change="toggleItem(item)"
        />
        <span
          class="flex-1 text-sm truncate"
          :class="
            item.completed
              ? 'text-n-slate-10 line-through'
              : 'text-n-slate-12'
          "
          :title="item.title"
        >
          {{ item.title }}
        </span>
        <button
          type="button"
          class="opacity-0 group-hover:opacity-100 text-n-slate-9 hover:text-n-ruby-11 flex-shrink-0"
          :aria-label="t('TICKET.DETAIL.CHECKLISTS.DELETE')"
          @click="removeItem(item)"
        >
          <Icon icon="i-lucide-trash-2" class="size-3.5" />
        </button>
      </li>
    </ul>

    <form class="flex items-center gap-2 pt-1" @submit.prevent="attachChecklist">
      <select
        v-model="selectedChecklistId"
        class="flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none min-w-0"
      >
        <option value="">{{ t('CHECKLISTS.SELECT.PLACEHOLDER') }}</option>
        <option v-for="cl in checklists" :key="cl.id" :value="cl.id">
          {{ cl.name }} ({{ cl.items?.length || 0 }})
        </option>
      </select>
      <NextButton
        size="sm"
        type="submit"
        icon="i-lucide-list-plus"
        :label="t('TICKET.DETAIL.CHECKLISTS.ATTACH_BUTTON')"
        :disabled="!selectedChecklistId"
        :is-loading="isSubmitting"
      />
    </form>
  </section>
</template>
