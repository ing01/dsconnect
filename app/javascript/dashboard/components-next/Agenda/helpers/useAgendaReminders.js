import { ref, watch, onUnmounted } from 'vue';
import { parseISO, differenceInMinutes } from 'date-fns';

// Chave no localStorage: por evento + start_at (cobre ocorrências recorrentes).
const dismissedKey = id => `agenda-reminder-dismissed-${id}`;

const isDismissed = reminderKey => {
  try {
    return !!localStorage.getItem(reminderKey);
  } catch {
    return false;
  }
};

const markDismissed = reminderKey => {
  try {
    localStorage.setItem(reminderKey, '1');
  } catch {
    // ignore
  }
};

// Chave única por ocorrência: usa o id + start_at para distinguir ocorrências
// de séries recorrentes, que compartilham o mesmo id.
const reminderKey = event => dismissedKey(`${event.id}-${event.start_at}`);

export function useAgendaReminders(eventsRef) {
  const activeReminders = ref([]);

  const check = () => {
    const now = new Date();

    const triggered = (eventsRef.value || []).filter(event => {
      if (!event.reminder_minutes_before || event.all_day) return false;

      const key = reminderKey(event);
      if (isDismissed(key)) return false;

      const start = parseISO(event.start_at);
      const minutesUntil = differenceInMinutes(start, now);

      // Dispara quando falta <= reminder_minutes_before e o evento ainda não começou
      // há mais de 1 min (janela: entre -1min e +reminder_minutes_before).
      return minutesUntil <= event.reminder_minutes_before && minutesUntil >= -1;
    });

    // Adiciona apenas os que ainda não estão ativos.
    const activeIds = new Set(activeReminders.value.map(r => reminderKey(r)));
    for (const event of triggered) {
      if (!activeIds.has(reminderKey(event))) {
        activeReminders.value = [...activeReminders.value, event];
      }
    }
  };

  const dismiss = event => {
    markDismissed(reminderKey(event));
    activeReminders.value = activeReminders.value.filter(
      r => reminderKey(r) !== reminderKey(event)
    );
  };

  // Verifica imediatamente e depois a cada 30 segundos.
  check();
  const interval = setInterval(check, 30_000);
  onUnmounted(() => clearInterval(interval));

  // Quando a lista de eventos muda (nova busca), verifica de novo.
  watch(eventsRef, check, { deep: false });

  return { activeReminders, dismiss };
}
