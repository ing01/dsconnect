<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  ticketId: { type: [Number, String], required: true },
  // Os responsaveis de cada nivel, para o resumo dizer de quem e cada tempo.
  // Vazio quando a Mesa nao usa niveis, e ai o resumo nem aparece.
  levelAssignees: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const store = useStore();

const CATEGORIES = ['implantacao', 'desenvolvimento', 'dev_geral'];

const category = ref('implantacao');
const hours = ref('');
const workedOn = ref(new Date().toISOString().split('T')[0]);
const note = ref('');
const isSubmitting = ref(false);

const entries = computed(
  () => store.getters['ticketTimeEntries/getEntriesByTicket'](props.ticketId) || []
);

const totalHours = computed(() =>
  entries.value.reduce((sum, entry) => sum + Number(entry.hours || 0), 0)
);

// Quanto cada nivel gastou neste ticket, que e a leitura pedida:
// "Responsavel 1: Joao - 01:35 / Responsavel 2: Carlos - 03:20".
const hoursByLevel = computed(() =>
  Object.entries(props.levelAssignees).map(([level, name]) => ({
    level: Number(level),
    name,
    hours: entries.value
      .filter(entry => Number(entry.level) === Number(level))
      .reduce((sum, entry) => sum + Number(entry.hours || 0), 0),
  }))
);

const showLevelSummary = computed(() => hoursByLevel.value.length > 0);

const categoryLabel = value => t(`TICKET.DETAIL.TIME_ENTRIES.CATEGORY.${value.toUpperCase()}`);

const load = () => store.dispatch('ticketTimeEntries/getByTicket', props.ticketId);

const resetForm = () => {
  hours.value = '';
  note.value = '';
};

const addEntry = async () => {
  const parsedHours = Number(hours.value);
  if (!parsedHours || parsedHours <= 0 || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    await store.dispatch('ticketTimeEntries/create', {
      ticketId: props.ticketId,
      category: category.value,
      hours: parsedHours,
      worked_on: workedOn.value,
      note: note.value.trim(),
    });
    resetForm();
  } catch (error) {
    useAlert(parseAPIErrorResponse(error) || t('TICKET.DETAIL.TIME_ENTRIES.ADD_ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const removeEntry = async entry => {
  try {
    await store.dispatch('ticketTimeEntries/delete', {
      ticketId: props.ticketId,
      entryId: entry.id,
    });
  } catch (error) {
    useAlert(t('TICKET.DETAIL.TIME_ENTRIES.DELETE_ERROR'));
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
        {{ t('TICKET.DETAIL.TIME_ENTRIES.TITLE') }}
      </h2>
      <span v-if="totalHours" class="text-xs font-medium text-n-slate-11">
        {{ t('TICKET.DETAIL.TIME_ENTRIES.TOTAL') }}: {{ totalHours }}h
      </span>
    </div>

    <!-- O corte por nivel, antes da lista: e a resposta que se procura ao
         abrir a aba, e a lista detalha o que ela resume. -->
    <div
      v-if="showLevelSummary"
      class="grid grid-cols-1 gap-2 sm:grid-cols-2 min-w-0"
    >
      <div
        v-for="row in hoursByLevel"
        :key="row.level"
        class="flex flex-col gap-0.5 px-3 py-2 rounded-lg bg-n-alpha-1 min-w-0"
      >
        <span class="text-xs text-n-slate-10">
          {{ t('TICKET.DETAIL.TIME_ENTRIES.LEVEL', { level: row.level }) }}
        </span>
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ row.name || t('TICKET.FORM.ASSIGNEE.NONE') }}
        </span>
        <span class="text-sm text-n-slate-11">{{ row.hours }}h</span>
      </div>
    </div>

    <p
      v-if="!entries.length"
      class="flex items-center gap-2 text-sm text-n-slate-10"
    >
      <Icon icon="i-lucide-clock-3" class="size-4 flex-shrink-0" />
      {{ t('TICKET.DETAIL.TIME_ENTRIES.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-1.5">
      <li
        v-for="entry in entries"
        :key="entry.id"
        class="group flex items-start justify-between gap-2 px-3 py-2 rounded-lg bg-n-alpha-1 min-w-0"
      >
        <div class="flex flex-col gap-0.5 min-w-0">
          <span class="text-sm font-medium text-n-slate-12">
            {{ entry.hours }}h — {{ categoryLabel(entry.category) }}
          </span>
          <span class="text-xs text-n-slate-10">
            {{ entry.worked_on }}
            <template v-if="entry.user_name"> · {{ entry.user_name }}</template>
            <template v-if="entry.level">
              ·
              {{ t('TICKET.DETAIL.TIME_ENTRIES.LEVEL', { level: entry.level }) }}
            </template>
          </span>
          <span v-if="entry.note" class="text-xs text-n-slate-11 truncate" :title="entry.note">
            {{ entry.note }}
          </span>
        </div>
        <button
          type="button"
          class="opacity-0 group-hover:opacity-100 text-n-slate-9 hover:text-n-ruby-11 flex-shrink-0"
          :aria-label="t('TICKET.DETAIL.TIME_ENTRIES.DELETE')"
          @click="removeEntry(entry)"
        >
          <Icon icon="i-lucide-trash-2" class="size-3.5" />
        </button>
      </li>
    </ul>

    <form
      class="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-2 border-t border-n-weak"
      @submit.prevent="addEntry"
    >
      <select
        v-model="category"
        class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
      >
        <option v-for="cat in CATEGORIES" :key="cat" :value="cat">
          {{ categoryLabel(cat) }}
        </option>
      </select>
      <input
        v-model="hours"
        type="number"
        min="0.25"
        step="0.25"
        class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
        :placeholder="t('TICKET.DETAIL.TIME_ENTRIES.HOURS_PLACEHOLDER')"
      />
      <input
        v-model="workedOn"
        type="date"
        class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
      />
      <input
        v-model="note"
        type="text"
        class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
        :placeholder="t('TICKET.DETAIL.TIME_ENTRIES.NOTE_PLACEHOLDER')"
      />
      <NextButton
        size="sm"
        type="submit"
        icon="i-lucide-plus"
        class="col-span-2 sm:col-span-4"
        :label="t('TICKET.DETAIL.TIME_ENTRIES.ADD_BUTTON')"
        :disabled="!hours || Number(hours) <= 0"
        :is-loading="isSubmitting"
      />
    </form>
  </section>
</template>
