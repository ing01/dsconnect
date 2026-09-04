<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import CalendarEventFormDialog from 'dashboard/components-next/Agenda/CalendarEventFormDialog.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();

const showForm = ref(false);

const ticket = computed(() => store.getters['tickets/getTicket'](props.ticketId));
const events = computed(
  () => store.getters['calendarEvents/getEventsByTicket'](props.ticketId) || []
);

const load = () =>
  store.dispatch('calendarEvents/getByTicket', { ticketId: props.ticketId });

const formatRange = event => {
  const start = new Date(event.start_at).toLocaleString();
  const end = new Date(event.end_at).toLocaleTimeString();
  return `${start} — ${end}`;
};

const openForm = () => {
  showForm.value = true;
};
const closeForm = () => {
  showForm.value = false;
};

const submitEvent = async payload => {
  try {
    await store.dispatch('calendarEvents/create', payload);
    useAlert(t('TICKET.DETAIL.APPOINTMENTS.CREATE_SUCCESS'));
    closeForm();
    load();
  } catch (error) {
    useAlert(t('TICKET.DETAIL.APPOINTMENTS.CREATE_ERROR'));
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
        {{ t('TICKET.DETAIL.APPOINTMENTS.TITLE') }}
      </h2>
      <NextButton
        v-if="ticket?.team_id"
        type="button"
        faded
        slate
        size="xs"
        icon="i-lucide-calendar-plus"
        :label="t('TICKET.DETAIL.APPOINTMENTS.NEW_BUTTON')"
        @click="openForm"
      />
    </div>

    <p
      v-if="!events.length"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-calendar" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.APPOINTMENTS.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-2">
      <li
        v-for="event in events"
        :key="event.id"
        class="flex flex-col gap-1 px-3 py-2 rounded-lg bg-n-alpha-1 min-w-0"
      >
        <span
          class="text-sm font-medium text-n-slate-12 truncate"
          :title="event.title"
        >
          {{ event.title }}
        </span>
        <span class="text-xs text-n-slate-10">{{ formatRange(event) }}</span>
        <span
          v-if="(event.attendees || []).length"
          class="text-xs text-n-slate-10 truncate"
        >
          {{ event.attendees.map(attendee => attendee.name).join(', ') }}
        </span>
      </li>
    </ul>

    <woot-modal v-model:show="showForm" size="medium" :on-close="closeForm">
      <CalendarEventFormDialog
        v-if="ticket?.team_id"
        :team-id="ticket.team_id"
        :preset-ticket-ids="[Number(ticketId)]"
        @close="closeForm"
        @submit="submitEvent"
      />
    </woot-modal>
  </section>
</template>
