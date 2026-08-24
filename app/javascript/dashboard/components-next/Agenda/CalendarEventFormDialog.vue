<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { format, parseISO, addMinutes } from 'date-fns';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { colorForAgent } from './helpers/agentColorHelper';

const props = defineProps({
  event: {
    type: Object,
    default: null,
  },
  teamId: {
    type: [Number, String],
    required: true,
  },
  initialStart: {
    type: Date,
    default: null,
  },
});

const emit = defineEmits(['close', 'submit', 'delete']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.event);
const teamMembers = useMapGetter('teamMembers/getTeamMembers');
const allTickets = useMapGetter('tickets/getTicketsList');

const toLocalInputValue = date => format(date, "yyyy-MM-dd'T'HH:mm");

const buildInitialForm = () => {
  if (props.event) {
    return {
      title: props.event.title,
      description: props.event.description || '',
      all_day: props.event.all_day,
      start_at: toLocalInputValue(parseISO(props.event.start_at)),
      end_at: toLocalInputValue(parseISO(props.event.end_at)),
      location: props.event.location || '',
      attendee_ids: (props.event.attendees || []).map(attendee => attendee.id),
      ticket_ids: (props.event.tickets || []).map(ticket => ticket.id),
    };
  }

  const start = props.initialStart || new Date();
  const end = addMinutes(start, 30);
  return {
    title: '',
    description: '',
    all_day: false,
    start_at: toLocalInputValue(start),
    end_at: toLocalInputValue(end),
    location: '',
    attendee_ids: [],
    ticket_ids: [],
  };
};

const form = reactive(buildInitialForm());
const titleError = ref('');
const isSubmitting = ref(false);
const ticketSearchQuery = ref('');

const teamTickets = computed(() =>
  allTickets.value.filter(ticket => ticket.team_id === Number(props.teamId))
);
const filteredTickets = computed(() => {
  const query = ticketSearchQuery.value.trim().toLowerCase();
  if (!query) return teamTickets.value;
  return teamTickets.value.filter(ticket => ticket.title.toLowerCase().includes(query));
});

const toggleAttendee = id => {
  form.attendee_ids = form.attendee_ids.includes(id)
    ? form.attendee_ids.filter(attendeeId => attendeeId !== id)
    : [...form.attendee_ids, id];
};

const toggleTicket = id => {
  form.ticket_ids = form.ticket_ids.includes(id)
    ? form.ticket_ids.filter(ticketId => ticketId !== id)
    : [...form.ticket_ids, id];
};

watch(
  () => form.all_day,
  allDay => {
    if (!allDay) return;
    form.start_at = format(parseISO(form.start_at), 'yyyy-MM-dd') + 'T00:00';
    form.end_at = format(parseISO(form.end_at), 'yyyy-MM-dd') + 'T23:59';
  }
);

const handleSubmit = () => {
  if (!form.title.trim()) {
    titleError.value = t('AGENDA.FORM.TITLE.REQUIRED_ERROR');
    return;
  }
  if (new Date(form.end_at) < new Date(form.start_at)) {
    useAlert(t('AGENDA.FORM.END_BEFORE_START_ERROR'));
    return;
  }

  isSubmitting.value = true;
  emit('submit', {
    ...form,
    title: form.title.trim(),
    team_id: Number(props.teamId),
    start_at: new Date(form.start_at).toISOString(),
    end_at: new Date(form.end_at).toISOString(),
  });
};

onMounted(async () => {
  await store.dispatch('teamMembers/get', { teamId: props.teamId });
  await store.dispatch('tickets/fetchTickets');
});
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="isEditing ? t('AGENDA.FORM.EDIT_TITLE') : t('AGENDA.FORM.ADD_TITLE')"
    />
    <div class="px-8 pb-4 flex-1 overflow-y-auto">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
        <div class="flex flex-col gap-4">
          <woot-input
            v-model="form.title"
            :label="t('AGENDA.FORM.TITLE.LABEL')"
            :placeholder="t('AGENDA.FORM.TITLE.PLACEHOLDER')"
            :error="titleError"
            @input="titleError = ''"
          />

          <div class="flex gap-3">
            <label class="w-1/2">
              <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.START_AT') }}</span>
              <input
                v-model="form.start_at"
                :type="form.all_day ? 'date' : 'datetime-local'"
                class="w-full"
              />
            </label>
            <label class="w-1/2">
              <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.END_AT') }}</span>
              <input
                v-model="form.end_at"
                :type="form.all_day ? 'date' : 'datetime-local'"
                class="w-full"
              />
            </label>
          </div>

          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input v-model="form.all_day" type="checkbox" class="rounded" />
            {{ t('AGENDA.FORM.ALL_DAY') }}
          </label>

          <woot-input
            v-model="form.location"
            :label="t('AGENDA.FORM.LOCATION.LABEL')"
            :placeholder="t('AGENDA.FORM.LOCATION.PLACEHOLDER')"
          />

          <label>
            <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.DESCRIPTION.LABEL') }}</span>
            <textarea
              v-model="form.description"
              rows="3"
              class="w-full"
              :placeholder="t('AGENDA.FORM.DESCRIPTION.PLACEHOLDER')"
            />
          </label>
        </div>

        <div class="flex flex-col gap-4">
          <div v-if="teamMembers(teamId).length">
            <span class="block mb-1 text-sm text-n-slate-11">{{ t('AGENDA.FORM.ATTENDEES') }}</span>
            <p class="mb-1.5 text-xs text-n-slate-10">{{ t('AGENDA.FORM.ATTENDEES_COLOR_HINT') }}</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="member in teamMembers(teamId)"
                :key="member.id"
                type="button"
                class="flex items-center gap-1.5 pl-1 pr-2.5 py-1 rounded-full border text-sm transition-colors"
                :class="
                  form.attendee_ids.includes(member.id)
                    ? 'bg-n-blue-3 border-n-blue-6 text-n-blue-11'
                    : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-1'
                "
                @click="toggleAttendee(member.id)"
              >
                <span class="shrink-0 size-2 rounded-full" :style="{ backgroundColor: colorForAgent(member.id) }" />
                <Avatar :name="member.name" :src="member.thumbnail || member.avatar_url" :size="20" rounded-full />
                {{ member.name }}
              </button>
            </div>
          </div>

          <div class="flex flex-col flex-1 min-h-0">
            <span class="block mb-1 text-sm text-n-slate-11">{{ t('AGENDA.FORM.TICKETS') }}</span>
            <woot-input
              v-model="ticketSearchQuery"
              class="w-full"
              :placeholder="t('AGENDA.FORM.TICKETS_SEARCH_PLACEHOLDER')"
            />
            <div v-if="filteredTickets.length" class="mt-2 max-h-56 overflow-y-auto flex flex-col gap-1">
              <label
                v-for="ticket in filteredTickets"
                :key="ticket.id"
                class="flex items-center gap-2 px-2 py-1.5 rounded-md hover:bg-n-alpha-1 text-sm text-n-slate-12"
              >
                <input
                  type="checkbox"
                  class="rounded"
                  :checked="form.ticket_ids.includes(ticket.id)"
                  @change="toggleTicket(ticket.id)"
                />
                <span class="truncate">#{{ ticket.display_id }} {{ ticket.title }}</span>
              </label>
            </div>
            <p v-else class="mt-2 text-sm text-n-slate-11">{{ t('AGENDA.FORM.NO_TICKETS') }}</p>
          </div>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between gap-2 px-8 py-4 border-t border-n-weak flex-shrink-0">
      <NextButton
        v-if="isEditing"
        color="ruby"
        variant="ghost"
        :label="t('AGENDA.FORM.DELETE')"
        @click="emit('delete', event)"
      />
      <div class="flex items-center gap-2 ml-auto">
        <NextButton variant="ghost" color="slate" :label="t('AGENDA.FORM.CANCEL')" @click="emit('close')" />
        <NextButton :is-loading="isSubmitting" :label="t('AGENDA.FORM.SAVE')" @click="handleSubmit" />
      </div>
    </div>
  </div>
</template>
