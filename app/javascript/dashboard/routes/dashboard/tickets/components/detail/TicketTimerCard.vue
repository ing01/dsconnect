<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { formatClock } from '../../helpers/timeEntryFormat';

// O cronometro de apontamento: iniciar, pausar, continuar e finalizar (o tempo vira
// um apontamento da lista). O tempo e' contado no servidor; aqui so se desenha o
// relogio, entao recarregar a pagina ou abrir em outro aparelho nao perde nada.
const props = defineProps({
  ticketId: { type: [Number, String], required: true },
  // A categoria que combina com a Mesa do ticket (implantacao, desenvolvimento...).
  defaultCategory: { type: String, default: 'implantacao' },
});

const { t } = useI18n();
const store = useStore();

const CATEGORIES = ['implantacao', 'desenvolvimento', 'dev_geral'];
const categoryLabel = value =>
  t(`TICKET.DETAIL.TIME_ENTRIES.CATEGORY.${value.toUpperCase()}`);

// Ja vem na categoria da Mesa do ticket; se a pessoa escolher outra, a escolha dela vale.
const category = ref(props.defaultCategory);
const categoryTouched = ref(false);
watch(
  () => props.defaultCategory,
  value => {
    if (!categoryTouched.value) category.value = value;
  }
);
const note = ref('');
const isBusy = ref(false);
const confirmingDiscard = ref(false);

// Um cronometro por pessoa e por ticket: o da lista e' o meu.
const timer = computed(
  () => store.getters['ticketTimeEntries/getTimersByTicket'](props.ticketId)[0]
);
const isRunning = computed(() => timer.value?.status === 'running');

// O relogio anda de segundo em segundo; o valor de partida vem do servidor.
const now = ref(Date.now());
let ticker = null;

const elapsedSeconds = computed(() => {
  if (!timer.value) return 0;
  const sinceReceived = isRunning.value
    ? (now.value - timer.value.receivedAt) / 1000
    : 0;
  return timer.value.elapsed_seconds + Math.max(0, sinceReceived);
});
const clock = computed(() => formatClock(elapsedSeconds.value));

const load = () =>
  store.dispatch('ticketTimeEntries/getTimers', props.ticketId);

// Rodar uma acao do cronometro: bloqueia cliques repetidos e mostra o erro do servidor.
const run = async (action, payload = {}) => {
  if (isBusy.value) return null;
  isBusy.value = true;
  try {
    return await store.dispatch(`ticketTimeEntries/${action}`, {
      ticketId: props.ticketId,
      ...payload,
    });
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) ||
        t('TICKET.DETAIL.TIME_ENTRIES.TIMER.ERROR')
    );
    return null;
  } finally {
    isBusy.value = false;
  }
};

const start = async () => {
  const started = await run('startTimer', {
    category: category.value,
    note: note.value.trim(),
  });
  if (started) note.value = '';
};

const pause = () => run('pauseTimer', { timerId: timer.value.id });
const resume = () => run('resumeTimer', { timerId: timer.value.id });

const finish = async () => {
  const entry = await run('finishTimer', { timerId: timer.value.id });
  if (entry) useAlert(t('TICKET.DETAIL.TIME_ENTRIES.TIMER.FINISHED'));
};

// Descartar apaga o tempo sem lancar nada: pede uma confirmacao antes.
const discard = async () => {
  if (!confirmingDiscard.value) {
    confirmingDiscard.value = true;
    return;
  }
  confirmingDiscard.value = false;
  await run('discardTimer', { timerId: timer.value.id });
};

onMounted(() => {
  load();
  ticker = setInterval(() => {
    now.value = Date.now();
  }, 1000);
});
onBeforeUnmount(() => clearInterval(ticker));
watch(
  () => props.ticketId,
  () => {
    confirmingDiscard.value = false;
    categoryTouched.value = false;
    category.value = props.defaultCategory;
    load();
  }
);
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-alpha-1"
    data-testid="timer-card"
  >
    <!-- Sem cronometro: escolher a categoria, uma observacao e iniciar. -->
    <template v-if="!timer">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('TICKET.DETAIL.TIME_ENTRIES.TIMER.TITLE') }}
      </span>
      <div class="grid grid-cols-1 sm:grid-cols-[10rem_1fr_auto] gap-2">
        <select
          v-model="category"
          data-testid="timer-category"
          @change="categoryTouched = true"
          class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
        >
          <option v-for="cat in CATEGORIES" :key="cat" :value="cat">
            {{ categoryLabel(cat) }}
          </option>
        </select>
        <input
          v-model="note"
          type="text"
          data-testid="timer-note"
          class="h-9 px-2.5 rounded-lg border border-n-weak bg-n-solid-1 text-xs text-n-slate-12 focus:border-n-brand focus:outline-none"
          :placeholder="t('TICKET.DETAIL.TIME_ENTRIES.NOTE_PLACEHOLDER')"
          @keyup.enter="start"
        />
        <NextButton
          size="sm"
          icon="i-lucide-play"
          data-testid="timer-start"
          :label="t('TICKET.DETAIL.TIME_ENTRIES.TIMER.START')"
          :is-loading="isBusy"
          @click="start"
        />
      </div>
    </template>

    <!-- Com cronometro: o relogio e as acoes. -->
    <template v-else>
      <div class="flex items-center justify-between gap-2 min-w-0">
        <span
          class="flex items-center gap-1.5 text-xs font-medium"
          :class="isRunning ? 'text-n-teal-11' : 'text-n-amber-11'"
          data-testid="timer-status"
        >
          <Icon
            :icon="isRunning ? 'i-lucide-timer' : 'i-lucide-pause'"
            class="size-3.5"
          />
          {{
            isRunning
              ? t('TICKET.DETAIL.TIME_ENTRIES.TIMER.RUNNING')
              : t('TICKET.DETAIL.TIME_ENTRIES.TIMER.PAUSED')
          }}
          <span class="font-normal text-n-slate-11">
            · {{ categoryLabel(timer.category) }}
          </span>
        </span>
      </div>

      <div
        class="text-3xl font-semibold tabular-nums text-n-slate-12"
        role="timer"
        data-testid="timer-clock"
      >
        {{ clock }}
      </div>
      <span
        v-if="timer.note"
        class="text-xs truncate text-n-slate-11"
        :title="timer.note"
      >
        {{ timer.note }}
      </span>

      <div class="flex flex-wrap items-center gap-2">
        <NextButton
          v-if="isRunning"
          size="sm"
          icon="i-lucide-pause"
          color="slate"
          data-testid="timer-pause"
          :label="t('TICKET.DETAIL.TIME_ENTRIES.TIMER.PAUSE')"
          :disabled="isBusy"
          @click="pause"
        />
        <NextButton
          v-else
          size="sm"
          icon="i-lucide-play"
          data-testid="timer-resume"
          :label="t('TICKET.DETAIL.TIME_ENTRIES.TIMER.RESUME')"
          :disabled="isBusy"
          @click="resume"
        />
        <NextButton
          size="sm"
          icon="i-lucide-check"
          data-testid="timer-finish"
          :label="t('TICKET.DETAIL.TIME_ENTRIES.TIMER.FINISH')"
          :disabled="isBusy"
          @click="finish"
        />
        <NextButton
          size="sm"
          variant="ghost"
          :color="confirmingDiscard ? 'ruby' : 'slate'"
          icon="i-lucide-trash-2"
          data-testid="timer-discard"
          :label="
            confirmingDiscard
              ? t('TICKET.DETAIL.TIME_ENTRIES.TIMER.DISCARD_CONFIRM')
              : t('TICKET.DETAIL.TIME_ENTRIES.TIMER.DISCARD')
          "
          :disabled="isBusy"
          @click="discard"
        />
        <NextButton
          v-if="confirmingDiscard"
          size="sm"
          variant="ghost"
          color="slate"
          :label="t('TICKET.DETAIL.TIME_ENTRIES.TIMER.KEEP')"
          @click="confirmingDiscard = false"
        />
      </div>
    </template>
  </div>
</template>
