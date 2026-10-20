<script setup>
import { ref, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { parseISO, differenceInMinutes } from 'date-fns';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  events: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['open']);

const { t } = useI18n();

const active = ref([]);

const reminderKey = event => `${event.id}|${event.start_at}`;

const isDismissed = key => {
  try {
    return !!localStorage.getItem(`agenda-reminder-${key}`);
  } catch {
    return false;
  }
};

const markDismissed = key => {
  try {
    localStorage.setItem(`agenda-reminder-${key}`, '1');
  } catch {
    // ignore
  }
};

const check = () => {
  const now = new Date();
  const activeKeys = new Set(active.value.map(e => reminderKey(e)));

  for (const event of props.events) {
    if (!event.reminder_minutes_before || event.all_day) continue;

    const key = reminderKey(event);
    if (isDismissed(key) || activeKeys.has(key)) continue;

    const start = parseISO(event.start_at);
    const minutesUntil = differenceInMinutes(start, now);

    // Dispara quando estamos dentro da janela: entre 1 min depois do início
    // e antes (ou igual) ao momento configurado.
    if (minutesUntil <= event.reminder_minutes_before && minutesUntil >= -1) {
      active.value = [...active.value, event];
    }
  }
};

const dismiss = event => {
  markDismissed(reminderKey(event));
  active.value = active.value.filter(e => reminderKey(e) !== reminderKey(event));
};

const openEvent = event => {
  emit('open', event);
  dismiss(event);
};

const minutesUntilLabel = event => {
  const n = differenceInMinutes(parseISO(event.start_at), new Date());
  if (n <= 0) return t('AGENDA.REMINDER_TOAST.STARTS_NOW');
  return t('AGENDA.REMINDER_TOAST.STARTS_IN', { n });
};

watch(() => props.events, check, { deep: false });

let interval;
onMounted(() => {
  check();
  interval = setInterval(check, 30_000);
});
onUnmounted(() => clearInterval(interval));
</script>

<template>
  <Teleport to="body">
    <div
      v-if="active.length"
      class="fixed bottom-6 right-6 z-[9998] flex flex-col gap-2 w-80 max-w-[calc(100vw-2rem)]"
    >
      <TransitionGroup name="reminder" tag="div" class="flex flex-col gap-2">
        <div
          v-for="event in active.slice(0, 3)"
          :key="reminderKey(event)"
          class="flex flex-col gap-2 p-3 rounded-xl bg-n-solid-2 border border-n-weak shadow-xl"
        >
          <div class="flex items-start justify-between gap-2">
            <div class="flex items-center gap-1.5 text-xs font-semibold text-n-brand">
              <Icon icon="i-lucide-bell" class="size-3.5 shrink-0" />
              {{ t('AGENDA.REMINDER_TOAST.LABEL') }}
            </div>
            <button
              type="button"
              class="shrink-0 flex items-center justify-center rounded-full size-5 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
              :aria-label="t('AGENDA.REMINDER_TOAST.DISMISS')"
              @click="dismiss(event)"
            >
              <Icon icon="i-lucide-x" class="size-3.5" />
            </button>
          </div>

          <div>
            <p class="m-0 text-sm font-semibold text-n-slate-12 leading-snug">
              {{ event.title }}
            </p>
            <p class="m-0 mt-0.5 text-xs text-n-slate-11">
              {{ minutesUntilLabel(event) }}
            </p>
          </div>

          <button
            type="button"
            class="self-start text-xs font-medium text-n-brand hover:underline focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand rounded"
            @click="openEvent(event)"
          >
            {{ t('AGENDA.REMINDER_TOAST.OPEN') }}
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.reminder-enter-active { transition: all 0.25s ease-out; }
.reminder-leave-active { transition: all 0.2s ease-in; }
.reminder-enter-from,
.reminder-leave-to { opacity: 0; transform: translateX(1.5rem); }
</style>
