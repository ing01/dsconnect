/**
 * Quantas notificações o cliente tem agora, sem precisar abrir a aba.
 *
 * O `ref` é de MÓDULO (fora da função) de propósito: o menu lateral
 * (`ClientSidebar.vue`) e a própria tela de notificações precisam do mesmo
 * número ao vivo - o menu pra mostrar o selo, a tela pra mantê-lo certo
 * quando um item é dispensado, sem ir ao servidor de novo pra isso.
 */
import { ref } from 'vue';
import ClientAreaAPI from 'dashboard/api/clientArea';

const count = ref(0);

export function useClientNotificationsCount() {
  const refresh = async () => {
    try {
      const { data } = await ClientAreaAPI.notifications();
      count.value = data.length;
    } catch {
      // Falhar aqui não pode incomodar - o selo só fica desatualizado até a
      // próxima tentativa (próxima troca de tela, próximo refresh).
    }
  };

  return { count, refresh };
}
