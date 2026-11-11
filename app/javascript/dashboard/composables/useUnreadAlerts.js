import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

/**
 * Onde ha mensagem nao lida esperando a pessoa logada - para o "!" das abas do topo,
 * do menu lateral e da aba do navegador.
 *
 * - conversas: alguma conversa ABERTA, atribuida a mim, com mensagem nao lida;
 * - chat interno: alguma sala do Chat Interno com mensagem nao lida.
 */
export function useUnreadAlerts() {
  const conversationsAlert = useMapGetter('unreadAssigned/hasUnread');
  const internalChatCount = useMapGetter('internalChat/getUnreadCount');

  const conversations = computed(() => !!conversationsAlert.value);
  const internalChat = computed(() => Number(internalChatCount.value) > 0);
  const any = computed(() => conversations.value || internalChat.value);

  return { conversations, internalChat, any };
}
