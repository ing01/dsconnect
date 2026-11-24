import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import ConversationPanelAPI from 'dashboard/api/conversationPanel';

const EVENT_REFETCH_DELAY_MS = 2000;
const CLOCK_TICK_MS = 10000;

/**
 * Os dados do Painel de Conversas, sempre frescos:
 * - `teamId` (ref) filtra a tela toda por time; vazio = todos os times;
 * - busca ao abrir e a cada `refresh_seconds` (definido nas Configurações);
 * - busca de novo, com pequeno atraso, quando chega um evento em tempo real
 *   de conversa/mensagem (várias mudanças seguidas viram uma busca só);
 * - relógio local que roda a cada 10 s, só para o "esperando há..." andar sem
 *   nova requisição. `nowMs` já vem corrigido pela diferença de relógio entre
 *   o servidor e este navegador.
 */
export const useConversationPanel = (teamId = ref(null)) => {
  const data = ref(null);
  const isLoading = ref(true);
  const hasError = ref(false);
  const clock = ref(Date.now());
  const clockOffset = ref(0);

  let pollTimer = null;
  let tickTimer = null;
  let eventTimer = null;

  const nowMs = computed(() => clock.value + clockOffset.value);

  const fetchPanel = async () => {
    try {
      const { data: payload } = await ConversationPanelAPI.get(
        teamId.value ? { team_id: teamId.value } : {}
      );
      data.value = payload;
      clockOffset.value = Date.parse(payload.generated_at) - Date.now();
      hasError.value = false;
    } catch {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  };

  const scheduleRefetch = () => {
    clearTimeout(eventTimer);
    eventTimer = setTimeout(fetchPanel, EVENT_REFETCH_DELAY_MS);
  };

  const restartPolling = seconds => {
    clearInterval(pollTimer);
    pollTimer = setInterval(fetchPanel, Math.max(seconds || 30, 10) * 1000);
  };

  // Trocar de time busca na hora, sem esperar o próximo ciclo.
  watch(teamId, fetchPanel);

  watch(
    () => data.value?.settings?.refresh_seconds,
    seconds => restartPolling(seconds),
    { immediate: true }
  );

  onMounted(() => {
    fetchPanel();
    emitter.on(BUS_EVENTS.CONVERSATION_PANEL_CHANGED, scheduleRefetch);
    tickTimer = setInterval(() => {
      clock.value = Date.now();
    }, CLOCK_TICK_MS);
  });

  onBeforeUnmount(() => {
    emitter.off(BUS_EVENTS.CONVERSATION_PANEL_CHANGED, scheduleRefetch);
    clearInterval(pollTimer);
    clearInterval(tickTimer);
    clearTimeout(eventTimer);
  });

  return { data, isLoading, hasError, nowMs, refresh: fetchPanel };
};
