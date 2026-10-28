<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { format, parseISO, addMinutes } from 'date-fns';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { colorForAgent } from './helpers/agentColorHelper';
import TicketsAPI from 'dashboard/api/tickets';

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
  // Lets a caller (e.g. a Ticket's own "Novo compromisso" button) open this
  // dialog with that Ticket already linked, without needing the agent to find
  // and pick it again from the list below.
  presetTicketIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'submit', 'delete']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => !!props.event);
const teamMembers = useMapGetter('teamMembers/getTeamMembers');
// Busca so' os tickets da Mesa, direto da API, numa lista LOCAL deste
// dialogo - nao pelo `tickets/fetchTickets` do Vuex, que SUBSTITUI a lista
// global inteira (a mesma que a pagina de detalhe do ticket le pra montar a
// tela). Ja' aconteceu de abrir "Novo compromisso" de dentro de um ticket e
// a pagina ficar em branco por causa disso - o ticket aberto sumia da lista
// global assim que esse fetch sem filtro a sobrescrevia.
const teamTickets = ref([]);

const toLocalInputValue = date => format(date, "yyyy-MM-dd'T'HH:mm");

// 'never'/'on_date'/'after_count' e' so' estado de TELA - o formulario so'
// manda UM dos dois campos de termino pro servidor (ou nenhum, se "nunca
// termina"), nunca os dois. Ver `recurrenceEndType` em `handleSubmit`.
const recurrenceEndTypeFor = event => {
  if (event.recurrence_end_at) return 'on_date';
  if (event.recurrence_count) return 'after_count';
  return 'never';
};

const buildInitialForm = () => {
  if (props.event) {
    return {
      event_type: props.event.event_type || 'event',
      title: props.event.title,
      description: props.event.description || '',
      all_day: props.event.all_day,
      start_at: toLocalInputValue(parseISO(props.event.start_at)),
      end_at: toLocalInputValue(parseISO(props.event.end_at)),
      location: props.event.location || '',
      attendee_ids: (props.event.attendees || []).map(attendee => attendee.id),
      ticket_ids: (props.event.tickets || []).map(ticket => ticket.id),
      recurrence_frequency: props.event.recurrence_frequency || 'single',
      recurrence_interval: props.event.recurrence_interval || 1,
      recurrence_end_type: recurrenceEndTypeFor(props.event),
      recurrence_end_at: props.event.recurrence_end_at
        ? format(parseISO(props.event.recurrence_end_at), 'yyyy-MM-dd')
        : '',
      recurrence_count: props.event.recurrence_count || 5,
      reminder_minutes_before: props.event.reminder_minutes_before ?? null,
    };
  }

  const start = props.initialStart || new Date();
  const end = addMinutes(start, 30);
  return {
    event_type: 'event',
    title: '',
    description: '',
    all_day: false,
    start_at: toLocalInputValue(start),
    end_at: toLocalInputValue(end),
    location: '',
    attendee_ids: [],
    ticket_ids: [...props.presetTicketIds],
    recurrence_frequency: 'single',
    recurrence_interval: 1,
    recurrence_end_type: 'never',
    recurrence_end_at: '',
    recurrence_count: 5,
    reminder_minutes_before: null,
  };
};

const form = reactive(buildInitialForm());
const titleError = ref('');
const isSubmitting = ref(false);
const ticketSearchQuery = ref('');

const filteredTickets = computed(() => {
  const query = ticketSearchQuery.value.trim().toLowerCase();
  if (!query) return teamTickets.value;
  return teamTickets.value.filter(ticket => ticket.title.toLowerCase().includes(query));
});

const toggleAttendee = id => {
  form.attendee_ids = form.attendee_ids.includes(id)
    ? form.attendee_ids.filter(attendeeId => attendeeId !== id)
    : [...form.attendee_ids, id];
  attendeesError.value = '';
};

const toggleTicket = id => {
  form.ticket_ids = form.ticket_ids.includes(id)
    ? form.ticket_ids.filter(ticketId => ticketId !== id)
    : [...form.ticket_ids, id];
};

const isTimeOff = computed(() => form.event_type === 'time_off');
const attendeesError = ref('');

// Trocar pra "Folga" assume dia inteiro de cara (o caso comum) - o agente
// ainda pode desmarcar se for so' meio periodo. O contrario (voltando pra
// "Compromisso") nao mexe no que a pessoa ja tinha escolhido.
watch(
  () => form.event_type,
  eventType => {
    if (eventType !== 'time_off') return;
    form.all_day = true;
    form.ticket_ids = [];
    form.location = '';
  }
);

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
  // Uma folga sem ninguem marcado nao diz de quem e' a ausencia - nao faz
  // sentido existir sem isso, diferente de um compromisso comum (onde
  // participante e' so' informativo).
  if (isTimeOff.value && !form.attendee_ids.length) {
    attendeesError.value = t('AGENDA.FORM.ATTENDEES_REQUIRED_FOR_TIME_OFF_ERROR');
    return;
  }
  if (new Date(form.end_at) < new Date(form.start_at)) {
    useAlert(t('AGENDA.FORM.END_BEFORE_START_ERROR'));
    return;
  }

  isSubmitting.value = true;

  const payload = {
    ...form,
    title: form.title.trim(),
    team_id: Number(props.teamId),
    start_at: new Date(form.start_at).toISOString(),
    end_at: new Date(form.end_at).toISOString(),
    recurrence_interval: form.recurrence_frequency === 'single' ? null : Number(form.recurrence_interval),
    recurrence_end_at: form.recurrence_frequency !== 'single' && form.recurrence_end_type === 'on_date' ? form.recurrence_end_at : null,
    recurrence_count:
      form.recurrence_frequency !== 'single' && form.recurrence_end_type === 'after_count' ? Number(form.recurrence_count) : null,
  };
  delete payload.recurrence_end_type;

  emit('submit', payload);
};

onMounted(async () => {
  await store.dispatch('teamMembers/get', { teamId: props.teamId });
  const { data } = await TicketsAPI.get({ team_id: props.teamId });
  teamTickets.value = data.payload;
});
</script>

<template>
  <div class="flex flex-col h-auto max-h-[85vh] overflow-hidden">
    <woot-modal-header
      :header-title="isEditing ? t('AGENDA.FORM.EDIT_TITLE') : t('AGENDA.FORM.ADD_TITLE')"
    />
    <div class="px-8 pb-4 flex-1 overflow-y-auto">
      <div class="flex gap-1 p-1 mb-4 rounded-lg bg-n-alpha-1 w-fit">
        <button
          type="button"
          class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
          :class="!isTimeOff ? 'bg-n-solid-2 text-n-slate-12 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12'"
          @click="form.event_type = 'event'"
        >
          {{ t('AGENDA.FORM.EVENT_TYPE.EVENT') }}
        </button>
        <button
          type="button"
          class="flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
          :class="isTimeOff ? 'bg-n-solid-2 text-n-slate-12 shadow-sm' : 'text-n-slate-11 hover:text-n-slate-12'"
          @click="form.event_type = 'time_off'"
        >
          <span class="i-lucide-palmtree size-3.5" />
          {{ t('AGENDA.FORM.EVENT_TYPE.TIME_OFF') }}
        </button>
      </div>

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

          <div class="flex flex-col gap-2 pt-2 border-t border-n-weak">
            <label>
              <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.RECURRENCE.LABEL') }}</span>
              <select v-model="form.recurrence_frequency" class="w-full">
                <option value="single">{{ t('AGENDA.FORM.RECURRENCE.NONE') }}</option>
                <option value="daily">{{ t('AGENDA.FORM.RECURRENCE.DAILY') }}</option>
                <option value="weekly">{{ t('AGENDA.FORM.RECURRENCE.WEEKLY') }}</option>
                <option value="monthly">{{ t('AGENDA.FORM.RECURRENCE.MONTHLY') }}</option>
                <option value="yearly">{{ t('AGENDA.FORM.RECURRENCE.YEARLY') }}</option>
              </select>
            </label>

            <template v-if="form.recurrence_frequency !== 'single'">
              <label>
                <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.RECURRENCE.INTERVAL') }}</span>
                <input v-model.number="form.recurrence_interval" type="number" min="1" class="w-full" />
              </label>

              <div class="flex flex-col gap-1.5">
                <span class="block text-sm text-n-slate-11">{{ t('AGENDA.FORM.RECURRENCE.ENDS') }}</span>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.recurrence_end_type" type="radio" value="never" />
                  {{ t('AGENDA.FORM.RECURRENCE.NEVER') }}
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.recurrence_end_type" type="radio" value="on_date" />
                  {{ t('AGENDA.FORM.RECURRENCE.ON_DATE') }}
                  <input
                    v-model="form.recurrence_end_at"
                    type="date"
                    class="flex-1"
                    :disabled="form.recurrence_end_type !== 'on_date'"
                  />
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input v-model="form.recurrence_end_type" type="radio" value="after_count" />
                  {{ t('AGENDA.FORM.RECURRENCE.AFTER_COUNT') }}
                  <input
                    v-model.number="form.recurrence_count"
                    type="number"
                    min="1"
                    class="w-16"
                    :disabled="form.recurrence_end_type !== 'after_count'"
                  />
                </label>
              </div>
            </template>
          </div>

          <woot-input
            v-if="!isTimeOff"
            v-model="form.location"
            :label="t('AGENDA.FORM.LOCATION.LABEL')"
            :placeholder="t('AGENDA.FORM.LOCATION.PLACEHOLDER')"
          />

          <label v-if="!form.all_day">
            <span class="text-sm text-n-slate-11">{{ t('AGENDA.FORM.REMINDER.LABEL') }}</span>
            <select v-model.number="form.reminder_minutes_before" class="w-full">
              <option :value="null">{{ t('AGENDA.FORM.REMINDER.NONE') }}</option>
              <option :value="5">{{ t('AGENDA.FORM.REMINDER.MINUTES', { n: 5 }) }}</option>
              <option :value="10">{{ t('AGENDA.FORM.REMINDER.MINUTES', { n: 10 }) }}</option>
              <option :value="15">{{ t('AGENDA.FORM.REMINDER.MINUTES', { n: 15 }) }}</option>
              <option :value="30">{{ t('AGENDA.FORM.REMINDER.MINUTES', { n: 30 }) }}</option>
              <option :value="60">{{ t('AGENDA.FORM.REMINDER.HOUR') }}</option>
              <option :value="120">{{ t('AGENDA.FORM.REMINDER.HOURS', { n: 2 }) }}</option>
            </select>
          </label>

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
            <span class="block mb-1 text-sm text-n-slate-11">
              {{ isTimeOff ? t('AGENDA.FORM.ATTENDEES_TIME_OFF_LABEL') : t('AGENDA.FORM.ATTENDEES') }}
            </span>
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
            <p v-if="attendeesError" class="mt-1 text-xs text-n-ruby-11">{{ attendeesError }}</p>
          </div>

          <div v-if="!isTimeOff" class="flex flex-col flex-1 min-h-0">
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
