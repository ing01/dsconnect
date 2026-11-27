import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

// Quantas conversas guardar como "ja mostradas": o bastante para nao reabrir, sem
// deixar as preferencias do usuario crescerem para sempre.
export const SEEN_LIMIT = 200;

// A abertura automatica do "Resumo do cliente", por usuario. Vem ligada; so'
// fica desligada quando a pessoa desmarca.
export function useCustomerBriefingPreference() {
  const { uiSettings, updateUISettings } = useUISettings();

  const autoOpen = computed({
    get: () => uiSettings.value?.customer_briefing_auto_open !== false,
    set: value => updateUISettings({ customer_briefing_auto_open: value }),
  });

  const wasShown = key =>
    (uiSettings.value?.customer_briefing_seen || []).includes(key);

  const markShown = key => {
    const seen = uiSettings.value?.customer_briefing_seen || [];
    updateUISettings({
      customer_briefing_seen: [...seen, key].slice(-SEEN_LIMIT),
    });
  };

  return { autoOpen, wasShown, markShown };
}
