<script setup>
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();

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

onMounted(load);
watch(() => props.ticketId, load);
</script>

<template>
  <section
    class="rounded-xl border border-n-weak p-4 flex flex-col gap-3 min-w-0"
  >
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('TICKET.DETAIL.APPOINTMENTS.TITLE') }}
    </h2>

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
  </section>
</template>
